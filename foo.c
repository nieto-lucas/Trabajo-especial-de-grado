int source()
{
	return 42;
}

void sink(int y)
{
}


void foo()
{
	int x = source();
	if (x < MAX)
	{
		int y = 2 * x;
		sink(y);
	}
}

