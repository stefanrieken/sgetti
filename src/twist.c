#include <stdio.h>
#include <string.h>
#include <stdbool.h>

/**
 * Twist the wider ASCII range `{}` to ASCII range `[]`.
 * Call with '-n' to convert '\r' to '\n' and vice versa.
 * Call with `-SHOUT`, also reverse lower and uppercase.
 */
int main(int argc, char ** argv) {
    bool n = false;
    bool shout = false;

    for (int i=1;i<argc;i++) {
      if (strcmp(argv[i], "-n") == 0) n = true;
      else if (strcmp(argv[i], "-SHOUT") == 0) shout = true;
    }

    int ch;
    char start = argc > 1 ? 'a' : '{';

    while ((ch = fgetc(stdin)) != EOF) {
	if (ch >= start) ch -= 0x20;
	else if (n && ch == '\n') ch = '\r';
	else if (n && ch == '\r') ch = '\n';
	else if (shout && ch >= 'A' && ch <= 'Z') ch += 0x20;
	fputc(ch, stdout);
    }
    return 0;
}
