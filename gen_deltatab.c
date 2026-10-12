// Generates deltaTable in q16_lib.c: the value to add to the previous pixel for
// each delta opcode, dr * 2048 + dg * 32 + db modulo 65536.

#include <stdio.h>
#include <stdint.h>

int main()
{
	printf("static const uint16_t deltaTable[128] = {\n");

	for (int v = 0; v < 128; v++)
	{
		int dr = ((v >> 5) & 0x3) - 2;
		int dg = ((v >> 2) & 0x7) - 4;
		int db = (v & 0x3) - 2;

		uint16_t delta = (uint16_t)(dr * 2048 + dg * 32 + db);

		if (v % 8 == 0)
			printf("\t");
		printf("0x%04X%s", delta, v == 127 ? "\n" : (v % 8 == 7 ? ",\n" : ", "));
	}

	printf("};\n");
	return 0;
}
