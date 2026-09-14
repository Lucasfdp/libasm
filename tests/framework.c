#include "test.h"
#include <sys/mman.h>
#include <unistd.h>

int	g_pass = 0;
int	g_fail = 0;
int	g_skip = 0;
int	g_verbose = 0;

static const char	*g_suite = "?";

sigjmp_buf				g_fault_jmp;
volatile sig_atomic_t	g_fault_armed = 0;

static void	on_fault(int sig)
{
	if (g_fault_armed)
	{
		g_fault_armed = 0;
		siglongjmp(g_fault_jmp, sig);
	}
	signal(sig, SIG_DFL);
	raise(sig);
}

void	fault_guard_install(void)
{
	signal(SIGSEGV, on_fault);
	signal(SIGBUS, on_fault);
	signal(SIGILL, on_fault);
}

void	suite(const char *name)
{
	size_t	i;

	g_suite = name;
	printf(C_BLU "\n-- %s " C_RST C_DIM, name);
	i = strlen(name) + 4;
	while (i++ < 60)
		printf("-");
	printf(C_RST "\n");
}

void	check(int ok, const char *what, const char *detail)
{
	if (ok)
	{
		g_pass++;
		if (g_verbose)
			printf("  " C_GRN "ok  " C_RST "%s\n", what);
		return ;
	}
	g_fail++;
	printf("  " C_RED "FAIL" C_RST " %s::%s\n", g_suite, what);
	if (detail && *detail)
		printf("       " C_DIM "%s" C_RST "\n", detail);
}

void	skip_fn(const char *name)
{
	g_skip++;
	printf("  " C_YEL "skip" C_RST " %s " C_DIM "(not implemented yet)" C_RST "\n",
		name);
}

int	require(void *fnptr, const char *name)
{
	if (fnptr)
		return (1);
	skip_fn(name);
	return (0);
}

const char	*q(const char *s)
{
	static char	buf[4][160];
	static int	i = 0;
	char		*out;
	size_t		n;

	i = (i + 1) % 4;
	out = buf[i];
	if (!s)
		return ("(null)");
	n = strlen(s);
	if (n > 140)
		snprintf(out, sizeof(buf[0]), "\"%.60s\"...(%zu bytes)", s, n);
	else
		snprintf(out, sizeof(buf[0]), "\"%s\"", s);
	return (out);
}

/*
** Two pages. Second one is PROT_NONE. The string is copied so that its
** terminating NUL is the last readable byte before the guard.
*/
char	*guard_str(const char *src)
{
	size_t	len;
	long	page;
	char	*base;
	char	*start;

	len = strlen(src);
	page = sysconf(_SC_PAGESIZE);
	base = mmap(NULL, page * 2, PROT_READ | PROT_WRITE,
			MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
	if (base == MAP_FAILED)
		return (NULL);
	if (mprotect(base + page, page, PROT_NONE) != 0)
		return (NULL);
	start = base + page - (len + 1);
	memcpy(start, src, len + 1);
	return (start);
}

void	guard_free(char *p)
{
	long	page;
	size_t	off;

	if (!p)
		return ;
	page = sysconf(_SC_PAGESIZE);
	off = (size_t)((unsigned long)p % (unsigned long)page);
	munmap(p - off, page * 2);
}
