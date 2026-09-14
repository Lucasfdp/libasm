#include "test.h"
#include <unistd.h>

static char	*rand_str(size_t n, int allow_high)
{
	char	*s;
	size_t	i;

	s = malloc(n + 1);
	for (i = 0; i < n; i++)
	{
		if (allow_high)
			s[i] = (char)(1 + rand() % 255);
		else
			s[i] = (char)('a' + rand() % 26);
	}
	s[n] = '\0';
	return (s);
}

/* ------------------------------------------------------------------ strlen */

void	test_strlen(void)
{
	char		buf[256];
	char		*r;
	char		*g;
	size_t		i;
	size_t		got;
	char		detail[256];

	suite("ft_strlen");
	if (!require((void *)ft_strlen, "ft_strlen"))
		return ;

	check(ft_strlen("") == 0, "empty string -> 0", NULL);
	check(ft_strlen("a") == 1, "one char -> 1", NULL);
	check(ft_strlen("hello, world") == 12, "plain string", NULL);
	check(ft_strlen("\x80\xff\xfe") == 3, "high-bit bytes counted", NULL);

	/* every length 0..200: catches off-by-one in unrolled loops */
	for (i = 0; i <= 200; i++)
	{
		memset(buf, 'x', i);
		buf[i] = '\0';
		got = ft_strlen(buf);
		if (got != i)
		{
			snprintf(detail, sizeof(detail),
				"len %zu returned %zu", i, got);
			check(0, "length sweep 0..200", detail);
			break ;
		}
	}
	if (i > 200)
		check(1, "length sweep 0..200", NULL);

	/* random, against libc */
	for (i = 0; i < 500; i++)
	{
		r = rand_str(rand() % 4096, 1);
		if (ft_strlen(r) != strlen(r))
		{
			snprintf(detail, sizeof(detail),
				"got %zu want %zu on %s", ft_strlen(r), strlen(r), q(r));
			check(0, "500 random strings vs libc", detail);
			free(r);
			break ;
		}
		free(r);
	}
	if (i == 500)
		check(1, "500 random strings vs libc", NULL);

	/* over-read detector: NUL sits on the last byte before an unmapped page */
	g = guard_str("abcdefghijklmnopqrstuvwxyz0123456789");
	if (g)
	{
		SAFE("no read past the terminating NUL",
			"SIGSEGV: your loop reads bytes beyond the NUL. Fine on a normal "
			"heap string, fatal when the NUL is the last byte of a page.",
			check(ft_strlen(g) == 36, "no read past the terminating NUL",
				"wrong length at a page boundary"));
		guard_free(g);
	}
	g = guard_str("");
	if (g)
	{
		SAFE("empty string at page edge", "SIGSEGV on an empty string",
			check(ft_strlen(g) == 0, "empty string at page edge", NULL));
		guard_free(g);
	}
}

/* ------------------------------------------------------------------ strcpy */

void	test_strcpy(void)
{
	char	dst[1024];
	char	*src;
	char	*ret;
	size_t	i;
	int		clean;
	char	detail[256];

	suite("ft_strcpy");
	if (!require((void *)ft_strcpy, "ft_strcpy"))
		return ;

	memset(dst, '#', sizeof(dst));
	ret = ft_strcpy(dst, "");
	check(ret == dst, "returns dst", NULL);
	check(dst[0] == '\0', "empty string copies just the NUL", NULL);
	check(dst[1] == '#', "does not touch byte after the NUL", NULL);

	memset(dst, '#', sizeof(dst));
	ft_strcpy(dst, "hello");
	check(memcmp(dst, "hello", 6) == 0, "plain copy", q(dst));
	check(dst[6] == '#', "no overflow past the NUL", NULL);

	/* every length 0..300, with a canary wall after the destination */
	for (i = 0; i <= 300; i++)
	{
		src = rand_str(i, 1);
		memset(dst, '#', sizeof(dst));
		ret = ft_strcpy(dst, src);
		clean = (ret == dst) && (memcmp(dst, src, i + 1) == 0)
			&& (dst[i + 1] == '#');
		if (!clean)
		{
			snprintf(detail, sizeof(detail),
				"length %zu: %s", i, dst[i + 1] != '#'
				? "wrote past the terminating NUL" : "content mismatch");
			check(0, "length sweep 0..300 with canary", detail);
			free(src);
			break ;
		}
		free(src);
	}
	if (i > 300)
		check(1, "length sweep 0..300 with canary", NULL);

	/* misaligned destination: the copy must not assume alignment */
	memset(dst, '#', sizeof(dst));
	ft_strcpy(dst + 3, "misaligned destination pointer");
	check(strcmp(dst + 3, "misaligned destination pointer") == 0,
		"unaligned dst", q(dst + 3));
	check(dst[2] == '#', "unaligned dst: no write before dst", NULL);
}

/* ------------------------------------------------------------------ strcmp */

static int	same_sign(int a, int b)
{
	if (a == 0 && b == 0)
		return (1);
	if (a > 0 && b > 0)
		return (1);
	if (a < 0 && b < 0)
		return (1);
	return (0);
}

void	test_strcmp(void)
{
	static const char	*pairs[][2] = {
	{"", ""}, {"", "a"}, {"a", ""}, {"a", "a"}, {"a", "b"}, {"b", "a"},
	{"abc", "abd"}, {"abd", "abc"}, {"abc", "abcd"}, {"abcd", "abc"},
	{"hello world", "hello world"}, {"Hello", "hello"},
	{"\x7f", "\x80"}, {"\x80", "\x7f"}, {"\xff", "\x01"}, {"\x01", "\xff"},
	{"test\x80zz", "test\x7fzz"}, {"aaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaab"},
	{"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
	};
	size_t	i;
	char	*a;
	char	*b;
	char	*g1;
	char	*g2;
	char	detail[256];

	suite("ft_strcmp");
	if (!require((void *)ft_strcmp, "ft_strcmp"))
		return ;

	for (i = 0; i < sizeof(pairs) / sizeof(pairs[0]); i++)
	{
		if (!same_sign(ft_strcmp(pairs[i][0], pairs[i][1]),
				strcmp(pairs[i][0], pairs[i][1])))
		{
			snprintf(detail, sizeof(detail),
				"%s vs %s -> got %d, libc %d "
				"(bytes must be compared as UNSIGNED char)",
				q(pairs[i][0]), q(pairs[i][1]),
				ft_strcmp(pairs[i][0], pairs[i][1]),
				strcmp(pairs[i][0], pairs[i][1]));
			check(0, "curated pairs vs libc sign", detail);
			break ;
		}
	}
	if (i == sizeof(pairs) / sizeof(pairs[0]))
		check(1, "curated pairs vs libc sign", NULL);

	for (i = 0; i < 2000; i++)
	{
		a = rand_str(rand() % 64, 1);
		b = rand_str(rand() % 64, 1);
		if (i % 3 == 0 && strlen(a))
		{
			free(b);
			b = strdup(a);
			b[rand() % strlen(b)] ^= 0x80;
		}
		if (!same_sign(ft_strcmp(a, b), strcmp(a, b)))
		{
			snprintf(detail, sizeof(detail), "got %d, libc %d on %s / %s",
				ft_strcmp(a, b), strcmp(a, b), q(a), q(b));
			check(0, "2000 random pairs vs libc sign", detail);
			free(a);
			free(b);
			break ;
		}
		free(a);
		free(b);
	}
	if (i == 2000)
		check(1, "2000 random pairs vs libc sign", NULL);

	g1 = guard_str("identical");
	g2 = guard_str("identical");
	if (g1 && g2)
	{
		SAFE("equal strings at page edge",
			"SIGSEGV: on a full match you kept reading past the NUL",
			check(ft_strcmp(g1, g2) == 0, "equal strings at page edge",
				"non-zero result for identical strings"));
		guard_free(g1);
		guard_free(g2);
	}
}
