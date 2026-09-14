#include "test.h"
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

static const char	*errname(int e)
{
	if (e == EBADF)
		return ("EBADF");
	if (e == EFAULT)
		return ("EFAULT");
	if (e == EINVAL)
		return ("EINVAL");
	if (e == 0)
		return ("0 (untouched)");
	return (strerror(e));
}

static int	tmpf(const char *content)
{
	char	path[] = "/tmp/libasm_XXXXXX";
	int		fd;

	fd = mkstemp(path);
	if (fd < 0)
		return (-1);
	unlink(path);
	if (content && *content)
	{
		if (write(fd, content, strlen(content)) < 0)
			return (-1);
		lseek(fd, 0, SEEK_SET);
	}
	return (fd);
}

/* ------------------------------------------------------------------- write */

void	test_write(void)
{
	int		fd;
	char	buf[128];
	ssize_t	r;
	char	detail[256];

	suite("ft_write");
	if (!require((void *)ft_write, "ft_write"))
		return ;

	fd = tmpf(NULL);
	r = ft_write(fd, "hello", 5);
	check(r == 5, "returns the byte count", NULL);
	lseek(fd, 0, SEEK_SET);
	memset(buf, 0, sizeof(buf));
	if (read(fd, buf, 5) < 0)
		check(0, "readback", "host read() failed");
	check(memcmp(buf, "hello", 5) == 0, "bytes actually land in the fd", q(buf));
	close(fd);

	fd = tmpf(NULL);
	errno = 0;
	r = ft_write(fd, "x", 0);
	check(r == 0, "count 0 -> returns 0", NULL);
	close(fd);

	/* writes embedded NULs — count, not strlen */
	fd = tmpf(NULL);
	r = ft_write(fd, "ab\0cd", 5);
	check(r == 5, "count is honoured, not strlen", NULL);
	lseek(fd, 0, SEEK_SET);
	memset(buf, 0, sizeof(buf));
	if (read(fd, buf, 5) < 0)
		check(0, "readback", "host read() failed");
	check(memcmp(buf, "ab\0cd", 5) == 0, "embedded NUL written", NULL);
	close(fd);

	/* error path: return -1 AND set errno through __errno_location */
	errno = 0;
	r = ft_write(-1, "x", 1);
	snprintf(detail, sizeof(detail), "returned %zd, errno = %s (want -1 / EBADF)",
		r, errname(errno));
	check(r == -1 && errno == EBADF, "bad fd -> -1 and errno EBADF", detail);

	errno = 0;
	fd = tmpf(NULL);
	close(fd);
	r = ft_write(fd, "x", 1);
	snprintf(detail, sizeof(detail), "returned %zd, errno = %s", r,
		errname(errno));
	check(r == -1 && errno == EBADF, "closed fd -> -1 and errno EBADF", detail);

	/* errno must be left alone on success */
	fd = tmpf(NULL);
	errno = EINVAL;
	ft_write(fd, "ok", 2);
	check(errno == EINVAL, "success does not clobber errno",
		"a successful write must not overwrite errno");
	close(fd);
	errno = 0;
}

/* -------------------------------------------------------------------- read */

void	test_read(void)
{
	int		fd;
	char	buf[128];
	ssize_t	r;
	char	detail[256];

	suite("ft_read");
	if (!require((void *)ft_read, "ft_read"))
		return ;

	fd = tmpf("abcdefghij");
	memset(buf, 0, sizeof(buf));
	r = ft_read(fd, buf, 10);
	check(r == 10, "returns bytes read", NULL);
	check(memcmp(buf, "abcdefghij", 10) == 0, "content matches", q(buf));
	close(fd);

	fd = tmpf("abcdefghij");
	memset(buf, 0, sizeof(buf));
	r = ft_read(fd, buf, 4);
	check(r == 4 && memcmp(buf, "abcd", 4) == 0, "partial read", q(buf));
	r = ft_read(fd, buf, 100);
	check(r == 6, "second read returns the remainder", NULL);
	r = ft_read(fd, buf, 100);
	check(r == 0, "EOF -> 0", NULL);
	close(fd);

	fd = tmpf("x");
	r = ft_read(fd, buf, 0);
	check(r == 0, "count 0 -> returns 0", NULL);
	close(fd);

	errno = 0;
	r = ft_read(-1, buf, 1);
	snprintf(detail, sizeof(detail), "returned %zd, errno = %s (want -1 / EBADF)",
		r, errname(errno));
	check(r == -1 && errno == EBADF, "bad fd -> -1 and errno EBADF", detail);

	/* read from a write-only fd */
	fd = open("/dev/null", O_WRONLY);
	errno = 0;
	r = ft_read(fd, buf, 1);
	snprintf(detail, sizeof(detail), "returned %zd, errno = %s", r,
		errname(errno));
	check(r == -1 && errno == EBADF, "write-only fd -> -1 and errno EBADF",
		detail);
	close(fd);

	fd = tmpf("z");
	errno = EINVAL;
	ft_read(fd, buf, 1);
	check(errno == EINVAL, "success does not clobber errno", NULL);
	close(fd);
	errno = 0;
}

/* ------------------------------------------------------------------ strdup */

void	test_strdup(void)
{
	char	*src;
	char	*cpy;
	size_t	i;
	char	detail[256];

	suite("ft_strdup");
	if (!require((void *)ft_strdup, "ft_strdup"))
		return ;

	cpy = ft_strdup("");
	check(cpy != NULL, "empty string returns a pointer", NULL);
	if (cpy)
	{
		check(cpy[0] == '\0', "empty string is NUL-terminated", NULL);
		free(cpy);
	}

	cpy = ft_strdup("hello world");
	check(cpy && strcmp(cpy, "hello world") == 0, "content matches",
		q(cpy));
	check(cpy != NULL, "returns non-NULL", NULL);
	free(cpy);

	src = strdup("mutable original");
	cpy = ft_strdup(src);
	if (cpy)
	{
		check(cpy != src, "returns a NEW buffer, not the argument", NULL);
		cpy[0] = 'X';
		check(src[0] == 'm', "writing to the copy leaves the source alone",
			NULL);
		free(cpy);
	}
	free(src);

	for (i = 0; i <= 400; i++)
	{
		src = malloc(i + 1);
		memset(src, 'q', i);
		src[i] = '\0';
		cpy = ft_strdup(src);
		if (!cpy || strcmp(cpy, src) != 0)
		{
			snprintf(detail, sizeof(detail), "failed at length %zu", i);
			check(0, "length sweep 0..400 (run under valgrind too)", detail);
			free(src);
			free(cpy);
			break ;
		}
		free(src);
		free(cpy);
	}
	if (i > 400)
		check(1, "length sweep 0..400 (run under valgrind too)", NULL);

	/* the allocated block must be exactly len+1 and fully initialised —
	   valgrind is what actually proves this, so run `make valgrind` */
	cpy = ft_strdup("valgrind me");
	if (cpy)
	{
		check(strlen(cpy) == 11, "length preserved", NULL);
		free(cpy);
	}
}
