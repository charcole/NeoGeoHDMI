#include <stdio.h>
#include <string.h>
#include "font.h"

#define CHAR_WIDTH 6

unsigned char data[CHAR_WIDTH*96];

void fontCreate()
{
	int waiting=1;
	int c=0;
	int x;
	memset(data, 0, sizeof(data));
	for (x=0; x<width; x++)
	{
		if (header_data[8*width+x])
		{
			int k;
			for (k=0; k<8; k++)
			{
				data[c]|=header_data[k*width+x]<<k;
			}
			c++;
			waiting=0;
		}
		else if (!waiting)
		{
			while (c%CHAR_WIDTH)
			{
				c++;
			}
			waiting=1;	
		}
	}
}

int main()
{
	FILE *f=fopen("font.hex", "w");
	int address=0;
	int i, k;
	fontCreate();
	for (i=0; i<96; i++)
	{
		int checksum=0;
		fprintf(f, ":%02d%04X00", CHAR_WIDTH, address);
		checksum+=CHAR_WIDTH;
		checksum+=(address/256);
		checksum+=address&0xFF;
		//address++;
		for (k=0; k<CHAR_WIDTH; k++)
		{
			int o=data[i*CHAR_WIDTH+k];
			fprintf(f, "%02X", o);
			checksum+=o;
			address++;
		}
		fprintf(f, "%02X\n", (-checksum)&0xFF);
		checksum=0;
	}
	fprintf(f, ":00000001FF\n");
	fclose(f);
	return 0;
}
