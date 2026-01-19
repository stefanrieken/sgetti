#include <stdio.h>

/**
 * Twist the wider ASCII range `{}` to ASCII range `[]`.
 * When called with `-SHOUT`, also reverse lower and uppercase.
 */
int main(int argc, char ** argv) {
    int ch;
    char start = argc > 1 ? 'a' : '{';

    while ((ch = fgetc(stdin)) != EOF) {
	if (ch >= start) ch -= 0x20;
	else if (argc > 1 && ch >= 'A' && ch <= 'Z') ch += 0x20;
	fputc(ch, stdout);
    }
    return 0;
}
