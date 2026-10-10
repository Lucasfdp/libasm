#include "test.h"
#include <limits.h>

/* --------------------------------------------------------------- atoi_base */

static void	one_base(const char *str, const char *base, int want)
{
	int		got;
	char	what[160];
	char	detail[160];

	got = ft_atoi_base((char *)str, (char *)base);
	snprintf(what, sizeof(what), "atoi_base(%s, %s)", q(str), q(base));
	snprintf(detail, sizeof(detail), "got %d, want %d", got, want);
	check(got == want, what, detail);
}

void	test_atoi_base(void)
{
	suite("ft_atoi_base (bonus)");
	if (!require((void *)ft_atoi_base, "ft_atoi_base"))
		return ;

	one_base("0", "0123456789", 0);
	one_base("123", "0123456789", 123);
	one_base("-42", "0123456789", -42);
	one_base("+42", "0123456789", 42);
	one_base("   \t\n 42", "0123456789", 42);
	one_base("--42", "0123456789", 42);
	one_base("-+-42", "0123456789", 42);
	one_base("---42", "0123456789", -42);
	one_base("42abc", "0123456789", 42);
	one_base("abc", "0123456789", 0);
	one_base("", "0123456789", 0);
	one_base("2147483647", "0123456789", 2147483647);
	one_base("-2147483648", "0123456789", INT_MIN);

	one_base("ff", "0123456789abcdef", 255);
	one_base("FF", "0123456789abcdef", 0);
	one_base("-ff", "0123456789abcdef", -255);
	one_base("1010", "01", 10);
	one_base("poneyvif", "poneyvif", 342391);
	one_base("zz", "0123456789abcdefghijklmnopqrstuvwxyz", 1295);

	/* invalid bases must yield 0 */
	one_base("123", "", 0);
	one_base("123", "0", 0);
	one_base("123", "01+", 0);
	one_base("123", "01-", 0);
	one_base("123", "0 1", 0);
	one_base("123", "0\t1", 0);
	one_base("123", "0\n1", 0);
	one_base("123", "001", 0);
	one_base("123", "0123456780", 0);
}

/* -------------------------------------------------------------------- list */

# define BIG 1000

static t_list	*mk(void *data, t_list *next)
{
	t_list	*n;

	n = malloc(sizeof(t_list));
	n->data = data;
	n->next = next;
	return (n);
}

static void	free_list(t_list *l)
{
	t_list	*n;

	while (l)
	{
		n = l->next;
		free(l);
		l = n;
	}
}

/* List whose data pointers are v[0], v[1], ... v[n - 1], in that order. */
static t_list	*build(void **v, int n)
{
	t_list	*head;

	head = NULL;
	while (n-- > 0)
		head = mk(v[n], head);
	return (head);
}

/* Node count, or -1 if the list never reaches NULL (cycle). */
static int	count(t_list *l)
{
	int	n;

	n = 0;
	while (l)
	{
		if (++n > 100000)
			return (-1);
		l = l->next;
	}
	return (n);
}

/* Are the data pointers exactly v[0..n-1], in order, with nothing after? */
static int	has_order(t_list *l, void **v, int n)
{
	int	i;

	i = 0;
	while (i < n)
	{
		if (!l || l->data != v[i])
			return (0);
		l = l->next;
		i++;
	}
	return (l == NULL);
}

static void	*dat(t_list *l)
{
	return (l ? l->data : NULL);
}

static t_list	*nxt(t_list *l)
{
	return (l ? l->next : NULL);
}

static void	point(int *v, void **p, int n)
{
	int	i;

	i = 0;
	while (i < n)
	{
		p[i] = &v[i];
		i++;
	}
}

/* mode 0: ascending, 1: descending, 2: pseudo-random with duplicates
** (fixed seed, so a failure is reproducible). */
static void	gen(int *v, int n, int mode)
{
	unsigned int	s;
	int				i;

	s = 12345;
	i = 0;
	while (i < n)
	{
		s = s * 1103515245u + 12345u;
		if (mode == 0)
			v[i] = i;
		else if (mode == 1)
			v[i] = n - i;
		else
			v[i] = (int)((s >> 16) % 201u) - 100;
		i++;
	}
}

/* "3,1,2," — only for failure details. */
static void	dump_ints(t_list *l, char *out, size_t cap)
{
	size_t	len;
	int		k;

	len = 0;
	out[0] = '\0';
	k = 0;
	while (l && k++ < 100000)
	{
		if (len + 16 >= cap)
		{
			snprintf(out + len, cap - len, "...");
			return ;
		}
		if (l->data)
			len += snprintf(out + len, cap - len, "%d,", *(int *)l->data);
		else
			len += snprintf(out + len, cap - len, "NULL,");
		l = l->next;
	}
}

static int	joined(t_list *l, char *out, size_t cap)
{
	out[0] = '\0';
	while (l)
	{
		strncat(out, (char *)l->data, cap - strlen(out) - 2);
		strncat(out, ",", cap - strlen(out) - 2);
		l = l->next;
	}
	return (0);
}

static int	cmp_str(char *a, char *b)
{
	return (strcmp(a, b));
}

/*
** The int comparators return (a - b) * 256 on purpose. A cmp that only ever
** returned -1/0/1 would hide a whole family of bugs: testing just al, testing
** eax == 1, comparing against the wrong width... Here the low byte of every
** result is 0, and the magnitude is arbitrary, so only a real "sign of eax"
** check survives.
*/
static int	cmp_int(int *a, int *b)
{
	return ((*a - *b) * 256);
}

static int	cmp_int_desc(int *a, int *b)
{
	return ((*b - *a) * 256);
}

/* ---------------------------------------------------------------- size */

static void	t_size(void)
{
	int		v[BIG];
	void	*p[BIG];
	t_list	*head;
	char	buf[64];
	int		n;
	int		bad;

	point(v, p, BIG);
	check(ft_list_size(NULL) == 0, "size(NULL) == 0", NULL);
	head = mk("a", NULL);
	check(ft_list_size(head) == 1, "size of a 1-node list", NULL);
	free_list(head);
	head = mk("a", mk("b", NULL));
	check(ft_list_size(head) == 2, "size of a 2-node list", NULL);
	free_list(head);
	head = mk("a", mk("b", mk("c", NULL)));
	check(ft_list_size(head) == 3, "size of a 3-node list", NULL);
	joined(head, buf, sizeof(buf));
	check(strcmp(buf, "a,b,c,") == 0, "size does not modify the list", buf);
	free_list(head);
	head = mk(NULL, mk(NULL, mk(NULL, NULL)));
	check(ft_list_size(head) == 3, "size ignores the data pointers", NULL);
	free_list(head);
	bad = -1;
	n = 0;
	while (n <= 20 && bad < 0)
	{
		head = build(p, n);
		if (ft_list_size(head) != n)
			bad = n;
		free_list(head);
		n++;
	}
	snprintf(buf, sizeof(buf), "first wrong length: %d", bad);
	check(bad < 0, "size of every list from 0 to 20 nodes", buf);
	head = build(p, BIG);
	n = ft_list_size(head);
	snprintf(buf, sizeof(buf), "got %d, want %d", n, BIG);
	check(n == BIG, "size of a 1000-node list (counter is not 8-bit)", buf);
	free_list(head);
}

/* ---------------------------------------------------------- push_front */

static void	t_push(void)
{
	int		v[BIG];
	void	*p[BIG];
	void	*rev[BIG];
	char	a[] = "a";
	char	b[] = "b";
	char	c[] = "c";
	void	*abc[3];
	t_list	*head;
	t_list	*old;
	char	buf[64];
	int		i;

	abc[0] = a;
	abc[1] = b;
	abc[2] = c;
	head = NULL;
	ft_list_push_front(&head, c);
	check(head != NULL, "push_front onto an empty list creates a node", NULL);
	check(dat(head) == c, "push_front stores the data pointer itself", NULL);
	check(nxt(head) == NULL && count(head) == 1,
		"push_front: a lone node's next is NULL", NULL);
	old = head;
	ft_list_push_front(&head, b);
	check(head != old && nxt(head) == old && dat(head) == b,
		"push_front links the new node to the old head", NULL);
	ft_list_push_front(&head, a);
	snprintf(buf, sizeof(buf), "length %d", count(head));
	check(has_order(head, abc, 3), "push_front keeps newest-first order", buf);
	free_list(head);

	head = mk(b, mk(c, NULL));
	old = head;
	ft_list_push_front(&head, a);
	check(has_order(head, abc, 3) && nxt(head) == old,
		"push_front onto a list built elsewhere", NULL);
	free_list(head);

	head = NULL;
	ft_list_push_front(&head, NULL);
	check(head != NULL && dat(head) == NULL && count(head) == 1,
		"push_front accepts NULL data (still creates a node)", NULL);
	ft_list_push_front(&head, a);
	check(count(head) == 2 && dat(head) == a && dat(nxt(head)) == NULL,
		"push_front after a NULL-data node", NULL);
	free_list(head);

	point(v, p, BIG);
	head = NULL;
	i = 0;
	while (i < BIG)
	{
		ft_list_push_front(&head, p[i]);
		rev[i] = p[BIG - 1 - i];
		i++;
	}
	snprintf(buf, sizeof(buf), "length %d, want %d", count(head), BIG);
	check(has_order(head, rev, BIG), "1000 pushes: all there, reversed", buf);
	free_list(head);
}

/* ---------------------------------------------------------------- sort */

/* Sorted according to the same comparator, same length, and every original
** data pointer present exactly once (nothing lost, nothing duplicated). */
static int	is_sorted_perm(t_list *l, void **p, int n, int desc)
{
	t_list	*it;
	int		i;
	int		seen;
	int		r;

	if (count(l) != n)
		return (0);
	it = l;
	while (it && it->next)
	{
		r = desc ? cmp_int_desc(it->data, it->next->data)
			: cmp_int(it->data, it->next->data);
		if (r > 0)
			return (0);
		it = it->next;
	}
	i = -1;
	while (++i < n)
	{
		seen = 0;
		it = l;
		while (it)
		{
			seen += (it->data == p[i]);
			it = it->next;
		}
		if (seen != 1)
			return (0);
	}
	return (1);
}

static void	sort_case(const char *name, int *v, int n, int desc)
{
	void	*p[BIG];
	t_list	*head;
	char	what[96];
	char	buf[256];

	point(v, p, n);
	head = build(p, n);
	ft_list_sort(&head, desc ? (int (*)())cmp_int_desc : (int (*)())cmp_int);
	dump_ints(head, buf, sizeof(buf));
	snprintf(what, sizeof(what), "sort %s", name);
	check(is_sorted_perm(head, p, n, desc), what, buf);
	free_list(head);
}

# define SORT(name, desc, ...) \
	do { \
		int	a_[] = {__VA_ARGS__}; \
		sort_case(name, a_, (int)(sizeof(a_) / sizeof(a_[0])), desc); \
	} while (0)

static void	t_sort(void)
{
	int		big[BIG];
	t_list	*head;
	char	buf[256];

	head = mk("delta", mk("alpha", mk("charlie", mk("bravo", NULL))));
	ft_list_sort(&head, (int (*)())cmp_str);
	joined(head, buf, sizeof(buf));
	check(strcmp(buf, "alpha,bravo,charlie,delta,") == 0,
		"sorts strings ascending with cmp", buf);
	free_list(head);

	head = NULL;
	ft_list_sort(&head, (int (*)())cmp_int);
	check(head == NULL, "sort of an empty list is a no-op", NULL);

	SORT("a single node", 0, 42);
	SORT("two nodes, in order", 0, 1, 2);
	SORT("two nodes, swapped", 0, 2, 1);
	SORT("three nodes", 0, 3, 1, 2);
	SORT("already sorted", 0, 1, 2, 3, 4, 5);
	SORT("reversed", 0, 5, 4, 3, 2, 1);
	SORT("all equal", 0, 7, 7, 7, 7);
	SORT("duplicates", 0, 2, 1, 2, 1, 2);
	SORT("negatives", 0, -3, 5, 0, -10, 8);
	SORT("large values (cmp result is huge)", 0, 1000000, -1000000, 0, 7);
	SORT("honours cmp: descending order", 1, 1, 3, 2, 5, 4);
	gen(big, BIG, 0);
	sort_case("1000 nodes, already sorted", big, BIG, 0);
	gen(big, BIG, 1);
	sort_case("1000 nodes, reversed", big, BIG, 0);
	gen(big, BIG, 2);
	sort_case("1000 nodes, random with duplicates", big, BIG, 0);
	sort_case("1000 nodes, random, descending cmp", big, BIG, 1);
}

/* ------------------------------------------------------------ remove_if */

/* Instrumentation: what free_fct was given, and how cmp was called. */
static void	*g_freed[BIG + 1];
static int	g_nfreed;
static int	g_ncmp;
static int	g_badref;
static void	*g_ref;

static void	free_track(void *p)
{
	if (g_nfreed < BIG)
		g_freed[g_nfreed] = p;
	g_nfreed++;
}

static int	cmp_track(int *a, int *b)
{
	g_ncmp++;
	if ((void *)b != g_ref)
		g_badref++;
	return ((*a - *b) * 256);
}

/* Every removed data pointer freed exactly once, and nothing else freed. */
static int	freed_exactly(void **gone, int ngone)
{
	int	i;
	int	j;
	int	seen;

	if (g_nfreed != ngone)
		return (0);
	i = 0;
	while (i < ngone)
	{
		seen = 0;
		j = 0;
		while (j < g_nfreed)
			seen += (g_freed[j++] == gone[i]);
		if (seen != 1)
			return (0);
		i++;
	}
	return (1);
}

/* Removes every node equal to `ref`, then checks three separate things:
** the survivors, the free_fct calls, and how cmp was called. */
static void	rm_case(const char *name, int *vals, int n, int ref)
{
	void	*p[BIG];
	void	*keep[BIG];
	void	*gone[BIG];
	int		nkeep;
	int		ngone;
	int		i;
	t_list	*head;
	char	what[160];
	char	buf[256];

	nkeep = 0;
	ngone = 0;
	point(vals, p, n);
	i = -1;
	while (++i < n)
	{
		if (vals[i] == ref)
			gone[ngone++] = p[i];
		else
			keep[nkeep++] = p[i];
	}
	head = build(p, n);
	g_nfreed = 0;
	g_ncmp = 0;
	g_badref = 0;
	g_ref = &ref;
	ft_list_remove_if(&head, &ref, (int (*)())cmp_track, free_track);
	dump_ints(head, buf, sizeof(buf));
	snprintf(what, sizeof(what), "remove_if %s: survivors, in order", name);
	check(has_order(head, keep, nkeep), what, buf);
	snprintf(what, sizeof(what), "remove_if %s: free_fct once per removed", name);
	snprintf(buf, sizeof(buf), "free_fct called %d times, want %d",
		g_nfreed, ngone);
	check(freed_exactly(gone, ngone), what, buf);
	snprintf(what, sizeof(what), "remove_if %s: cmp(data, data_ref)", name);
	snprintf(buf, sizeof(buf), "cmp called %d times (want %d); "
		"%d calls had data_ref in the wrong slot", g_ncmp, n, g_badref);
	check(g_ncmp == n && g_badref == 0, what, buf);
	free_list(head);
}

# define RM(name, ref, ...) \
	do { \
		int	a_[] = {__VA_ARGS__}; \
		rm_case(name, a_, (int)(sizeof(a_) / sizeof(a_[0])), ref); \
	} while (0)

static void	t_remove(void)
{
	int		big[BIG];
	int		i;
	t_list	*head;
	t_list	*nx;
	char	buf[256];

	RM("head matches", 1, 1, 2, 3);
	RM("tail matches", 3, 1, 2, 3);
	RM("middle matches", 2, 1, 2, 3);
	RM("no match", 9, 1, 2, 3);
	RM("everything matches", 5, 5, 5, 5);
	RM("single node, match", 4, 4);
	RM("single node, no match", 5, 4);
	RM("consecutive in the middle", 2, 1, 2, 2, 2, 3);
	RM("consecutive at the head", 2, 2, 2, 1, 3);
	RM("consecutive at the tail", 2, 1, 3, 2, 2);
	RM("alternating", 2, 2, 1, 2, 1, 2);
	RM("head and tail both match", 7, 7, 1, 2, 7);
	i = -1;
	while (++i < BIG)
		big[i] = i % 10;
	rm_case("1000 nodes, every 10th", big, BIG, 3);
	i = -1;
	while (++i < BIG)
		big[i] = 6;
	rm_case("1000 nodes, all match", big, BIG, 6);

	g_nfreed = 0;
	g_ncmp = 0;
	head = NULL;
	ft_list_remove_if(&head, &i, (int (*)())cmp_track, free_track);
	check(head == NULL && g_nfreed == 0 && g_ncmp == 0,
		"remove_if on an empty list is a no-op", NULL);

	/* real heap data + real free(): `make valgrind` checks the rest */
	head = mk(strdup("x"), mk(strdup("y"), mk(strdup("x"),
					mk(strdup("z"), NULL))));
	ft_list_remove_if(&head, "x", (int (*)())cmp_str, free);
	joined(head, buf, sizeof(buf));
	check(strcmp(buf, "y,z,") == 0, "removes every match, incl. the head (strings)",
		buf);
	while (head)
	{
		free(head->data);
		nx = head->next;
		free(head);
		head = nx;
	}
	head = mk(strdup("q"), mk(strdup("q"), NULL));
	ft_list_remove_if(&head, "q", (int (*)())cmp_str, free);
	check(head == NULL, "removing everything leaves NULL (strings)", NULL);
}

/* ---------------------------------------------------------------- entry */

void	test_list(void)
{
	suite("ft_list_* (bonus)");
	if (require((void *)ft_list_size, "ft_list_size"))
		SAFE("ft_list_size", "crashed (SIGSEGV/SIGBUS/SIGILL)", t_size());
	if (require((void *)ft_list_push_front, "ft_list_push_front"))
		SAFE("ft_list_push_front", "crashed (SIGSEGV/SIGBUS/SIGILL)",
			t_push());
	if (require((void *)ft_list_sort, "ft_list_sort"))
		SAFE("ft_list_sort", "crashed (SIGSEGV/SIGBUS/SIGILL)", t_sort());
	if (require((void *)ft_list_remove_if, "ft_list_remove_if"))
		SAFE("ft_list_remove_if", "crashed (SIGSEGV/SIGBUS/SIGILL)",
			t_remove());
}
