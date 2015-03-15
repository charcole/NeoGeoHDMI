#include <stdio.h>
#include <string.h>
#include "neogeo.h"

#define width mwidth
#define height mheight
#define header_data mheader_data
#define header_data_cmap mheader_data_cmap
#include "messages.h"
#undef width
#undef height
#undef header_data
#undef header_data_cmap

#define CHAR_WIDTH 3

unsigned char data[CHAR_WIDTH*256+512];

void fontCreate()
{
	int x,y,c=0;
	memset(data, 0, sizeof(data));
	for (x=0; x<width; x++)
	{
		for (y=0; y<CHAR_WIDTH; y++)
		{
			int k;
			for (k=0; k<8; k++)
			{
				data[c]|=header_data[(k+y*8)*width+x]<<k;
			}
			c++;
		}
	}
	for (x=0; x<mwidth; x++)
	{
		int k;
		for (k=0; k<8; k++)
		{
			data[c]|=mheader_data[k*mwidth+x]<<k;
		}
		c++;
	}
	if (c!=sizeof(data))
		printf("Wrote wrong size\n");
}

int main()
{
	FILE *f=fopen("logo.hex", "w");
	int address=0;
	int i, k;
	fontCreate();
	for (i=0; i<sizeof(data); i++)
	{
		int checksum=0;
		int o=data[i]&0xFF;
		fprintf(f, ":%02d%04X00", 1, address);
		checksum+=1;
		checksum+=(address/256);
		checksum+=address&0xFF;
		fprintf(f, "%02X", o);
		checksum+=o;
		address++;
		fprintf(f, "%02X\n", (-checksum)&0xFF);
	}
	if (address!=sizeof(data))
		printf("Wrote wrong size output\n");
	fprintf(f, ":00000001FF\n");
	fclose(f);
	return 0;
}
