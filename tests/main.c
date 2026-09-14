#include "test.h"
#include <time.h>
#include <unistd.h>

static void	usage(const char *p)
{
	printf("usage: %s [-v] [suite ...]\n", p);
	printf("  suites: strlen strcpy strcmp write read strdup atoi list\n");
	printf("  no suite argument runs everything\n");
}

static int	wants(int argc, char **argv, const char *name)
{
	int	i;
	int	any;

	any = 0;
	i = 1;
	while (i < argc)
	{
		if (argv[i][0] != '-')
		{
			any = 1;
			if (strcmp(argv[i], name) == 0)
				return (1);
		}
		i++;
	}
	return (!any);
}

int	main(int argc, char **argv)
{
	int	i;

	srand((unsigned)time(NULL));
	fault_guard_install();
	i = 1;
	while (i < argc)
	{
		if (strcmp(argv[i], "-v") == 0)
			g_verbose = 1;
		else if (strcmp(argv[i], "-h") == 0)
			return (usage(argv[0]), 0);
		i++;
	}

	printf(C_BLU "libasm test suite" C_RST C_DIM
		"  (skip = not implemented yet)" C_RST "\n");

	if (wants(argc, argv, "strlen"))
		test_strlen();
	if (wants(argc, argv, "strcpy"))
		test_strcpy();
	if (wants(argc, argv, "strcmp"))
		test_strcmp();
	if (wants(argc, argv, "write"))
		test_write();
	if (wants(argc, argv, "read"))
		test_read();
	if (wants(argc, argv, "strdup"))
		test_strdup();
	if (wants(argc, argv, "atoi"))
		test_atoi_base();
	if (wants(argc, argv, "list"))
		test_list();

	printf("\n" C_DIM "------------------------------------------------"
		C_RST "\n");
	printf(C_GRN "%d passed" C_RST "   " C_RED "%d failed" C_RST "   "
		C_YEL "%d skipped" C_RST "\n", g_pass, g_fail, g_skip);
	if (g_fail == 0 && g_skip == 0)
		printf(C_GRN "everything green.\n" C_RST);
	else if (g_fail == 0)
		printf(C_YEL "no failures — keep implementing.\n" C_RST);
	return (g_fail != 0);
}
