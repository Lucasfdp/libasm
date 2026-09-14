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

static t_list	*mk(char *s, t_list *next)
{
	t_list	*n;

	n = malloc(sizeof(t_list));
	n->data = s;
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

static int	cmp_str(char *a, char *b)
{
	return (strcmp(a, b));
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

void	test_list(void)
{
	t_list	*head;
	char	buf[256];
	int		n;

	suite("ft_list_* (bonus)");

	/* size */
	if (require((void *)ft_list_size, "ft_list_size"))
	{
		check(ft_list_size(NULL) == 0, "size(NULL) == 0", NULL);
		head = mk("a", mk("b", mk("c", NULL)));
		n = ft_list_size(head);
		check(n == 3, "size of a 3-node list", NULL);
		free_list(head);
	}

	/* push_front */
	if (require((void *)ft_list_push_front, "ft_list_push_front"))
	{
		head = NULL;
		ft_list_push_front(&head, "c");
		ft_list_push_front(&head, "b");
		ft_list_push_front(&head, "a");
		check(head != NULL, "push_front onto empty list allocates", NULL);
		if (head)
		{
			joined(head, buf, sizeof(buf));
			check(strcmp(buf, "a,b,c,") == 0, "push_front order", buf);
			free_list(head);
		}
	}

	/* sort */
	if (require((void *)ft_list_sort, "ft_list_sort"))
	{
		head = mk("delta", mk("alpha", mk("charlie", mk("bravo", NULL))));
		ft_list_sort(&head, (int (*)())cmp_str);
		joined(head, buf, sizeof(buf));
		check(strcmp(buf, "alpha,bravo,charlie,delta,") == 0,
			"sorts ascending with cmp", buf);
		free_list(head);

		head = NULL;
		ft_list_sort(&head, (int (*)())cmp_str);
		check(head == NULL, "sort of an empty list is a no-op", NULL);

		head = mk("only", NULL);
		ft_list_sort(&head, (int (*)())cmp_str);
		check(head && strcmp((char *)head->data, "only") == 0,
			"sort of a single node", NULL);
		free_list(head);

		head = mk("b", mk("b", mk("a", NULL)));
		ft_list_sort(&head, (int (*)())cmp_str);
		joined(head, buf, sizeof(buf));
		check(strcmp(buf, "a,b,b,") == 0, "sort with duplicates", buf);
		free_list(head);
	}

	/* remove_if */
	if (require((void *)ft_list_remove_if, "ft_list_remove_if"))
	{
		head = mk(strdup("x"), mk(strdup("y"), mk(strdup("x"),
						mk(strdup("z"), NULL))));
		ft_list_remove_if(&head, "x", (int (*)())cmp_str, free);
		joined(head, buf, sizeof(buf));
		check(strcmp(buf, "y,z,") == 0, "removes every match, incl. the head",
			buf);
		while (head)
		{
			free(head->data);
			t_list *nx = head->next;
			free(head);
			head = nx;
		}

		head = mk(strdup("q"), mk(strdup("q"), NULL));
		ft_list_remove_if(&head, "q", (int (*)())cmp_str, free);
		check(head == NULL, "removing everything leaves NULL", NULL);

		head = NULL;
		ft_list_remove_if(&head, "q", (int (*)())cmp_str, free);
		check(head == NULL, "remove_if on empty list is a no-op", NULL);
	}
}
