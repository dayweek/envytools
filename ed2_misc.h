#ifndef ED2_TYPES_H
#define ED2_TYPES_H

#include <stdlib.h>

typedef unsigned long long ull;

char *ed2_str_deescape(char *str, ull *len);

#define ADDARRAY(a, e) \
	do { \
	if ((a ## num) >= (a ## max)) { \
		if (!(a ## max)) \
			(a ## max) = 16; \
		else \
			(a ## max) *= 2; \
		(a) = realloc((a), (a ## max)*sizeof(*(a))); \
	} \
	(a)[(a ## num)++] = (e); \
	} while(0)

#endif
