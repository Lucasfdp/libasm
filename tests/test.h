#ifndef TEST_H
# define TEST_H

# include <stddef.h>
# include <sys/types.h>
# include <stdio.h>
# include <string.h>
# include <stdlib.h>

/*
** ---------------------------------------------------------------------------
** libasm under test.
**
** Every prototype is declared `weak`: the suite links and runs even when a
** function isn't written yet, and simply reports it as SKIP. That means you
** can run `make test` from lesson 1 onward and watch SKIPs turn into PASSes.
**
** (The Makefile links libasm.a with --whole-archive so that weak references
** still pull in the members you HAVE implemented.)
** ---------------------------------------------------------------------------
*/

# define WEAK __attribute__((weak))

typedef struct s_list
{
	void			*data;
	struct s_list	*next;
}					t_list;

/* mandatory */
size_t	ft_strlen(const char *s) WEAK;
char	*ft_strcpy(char *dst, const char *src) WEAK;
int		ft_strcmp(const char *s1, const char *s2) WEAK;
ssize_t	ft_write(int fd, const void *buf, size_t count) WEAK;
ssize_t	ft_read(int fd, void *buf, size_t count) WEAK;
char	*ft_strdup(const char *s) WEAK;

/* bonus */
int		ft_atoi_base(char *str, char *base) WEAK;
int		ft_list_size(t_list *begin_list) WEAK;
void	ft_list_push_front(t_list **begin_list, void *data) WEAK;
void	ft_list_sort(t_list **begin_list, int (*cmp)()) WEAK;
void	ft_list_remove_if(t_list **begin_list, void *data_ref,
			int (*cmp)(), void (*free_fct)(void *)) WEAK;

/*
** ---------------------------------------------------------------------------
** Tiny assertion framework.
** ---------------------------------------------------------------------------
*/

extern int	g_pass;
extern int	g_fail;
extern int	g_skip;
extern int	g_verbose;

# define C_RED   "\033[31m"
# define C_GRN   "\033[32m"
# define C_YEL   "\033[33m"
# define C_BLU   "\033[34m"
# define C_DIM   "\033[2m"
# define C_RST   "\033[0m"

void	suite(const char *name);
void	check(int ok, const char *what, const char *detail);
void	skip_fn(const char *name);
int		require(void *fnptr, const char *name);

/* pretty-printers used in failure detail lines */
const char	*q(const char *s);

/*
** A read-only string placed so its final NUL sits on the very last byte of a
** mapped page, with an unmapped guard page right after. Any read past the NUL
** segfaults — which is exactly how you catch a 4/8/16-byte-at-a-time loop that
** runs off the end. Free with guard_free().
*/
char	*guard_str(const char *src);
void	guard_free(char *p);

/*
** Run `code` with SIGSEGV/SIGBUS turned into a clean FAIL line instead of a
** dead test run. Used around the guard-page checks: an asm routine that reads
** past the end of a string crashes there, and we want the report, not a core.
*/
# include <setjmp.h>
# include <signal.h>

extern sigjmp_buf			g_fault_jmp;
extern volatile sig_atomic_t	g_fault_armed;

void	fault_guard_install(void);

# define SAFE(what, detail, code)                      \
	do {                                               \
		if (sigsetjmp(g_fault_jmp, 1) == 0)            \
		{                                              \
			g_fault_armed = 1;                         \
			code;                                      \
			g_fault_armed = 0;                         \
		}                                              \
		else                                           \
		{                                              \
			g_fault_armed = 0;                         \
			check(0, what, detail);                    \
		}                                              \
	} while (0)

/* suites */
void	test_strlen(void);
void	test_strcpy(void);
void	test_strcmp(void);
void	test_write(void);
void	test_read(void);
void	test_strdup(void);
void	test_atoi_base(void);
void	test_list(void);

#endif
