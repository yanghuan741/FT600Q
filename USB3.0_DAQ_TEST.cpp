// USB3.0_DAQ_TEST.cpp : 定义控制台应用程序的入口点。
#include "stdafx.h" 
#include <initguid.h> // For DEFINE_GUID // 
#include "time.h"
// Define when linking with static library 
// Undefine when linking with dynamic library 
#define FTD3XX_STATIC  
// Include D3XX library
#include "FTD3XX.h" 
#pragma comment(lib, "FTD3XX.lib")
// Device Interface GUID. 
// Must match "DeviceInterfaceGUIDs" registry value specified in the INF file. 
DEFINE_GUID(GUID_DEVINTERFACE_IN_INF, 0x728CE52C,0xB9FD,0x40BC,0xA5,0x2E,0xB7,0x27,0x6E,0x2C,0xC8,0x69);

int _tmain(void)
{
	/////////////////////////////////////////////////////////////////////////////////// 
	// Single channel loopback test using synchronous write and read operations 
	/////////////////////////////////////////////////////////////////////////////////// 
	
	
	FT_STATUS ftStatus = FT_OK;
	FT_HANDLE ftHandle;
	GUID DeviceGUID[2] = { 0 };	
	// Open a device handle by GUID  
	memcpy(&DeviceGUID[0], &GUID_DEVINTERFACE_IN_INF, sizeof(GUID));
	ftStatus = FT_Create(&DeviceGUID[0], FT_OPEN_BY_GUID, &ftHandle);
	if (FT_FAILED(ftStatus))
	{		
		printf("FT_Create FALSE\n");
	}
	else
	{
		printf("FT_Create OK\n");
	}
	
	// Write and read loopback transfer 
	// 
	// Write to channel 1 ep 0x02 
	// 
	const UCHAR BUFFER_SIZE = 16;
	USHORT WRITE_DATA[BUFFER_SIZE];
	UCHAR acWriteBuf[BUFFER_SIZE*2];
	for (UCHAR i = 0; i < BUFFER_SIZE; i++)
	{
		WRITE_DATA[i] = i + 5555;
		//printf("WRITE_DATA[%d]=%d\n", i, WRITE_DATA[i]);
	}
	for (UCHAR i = 0; i < BUFFER_SIZE; i++)
	{
		acWriteBuf[2 * i] = (UCHAR)(WRITE_DATA[i]);
		acWriteBuf[2 * i + 1] = (UCHAR)(WRITE_DATA[i]>>8);
	}
	system("pause");
	ULONG ulBytesWritten = 0;
	ftStatus = FT_WritePipe(ftHandle, 0x02, acWriteBuf, sizeof(acWriteBuf), &ulBytesWritten, NULL);
	if (FT_FAILED(ftStatus))
	{
		FT_Close(ftHandle);
		printf("FT_WritePipe FALSE\n");		
	}
	else
	{
		printf("FT_WritePipe OK\n");
	}
	printf("ulBytesWritten : %d\n", ulBytesWritten);
	
	system("pause");
	// 
	// Read from channel 1 ep 0x82 
	// FT_ReadPipe is a blocking/synchronous function. 
	// It will not return until it has received all data requested 


	const ULONG READ_WORD = 8192; 
	const ULONG ReadBUFFER_SIZE = READ_WORD*2;
	UCHAR acReadBuf[ReadBUFFER_SIZE];
	USHORT Read_Result[ReadBUFFER_SIZE / 2];
	for (ULONG i = 0; i < ReadBUFFER_SIZE; i++)
	{
		acReadBuf[i] = 0;
	}
	
	ULONG ulBytesRead = 0;

	ftStatus = FT_ReadPipe(ftHandle, 0x82, acReadBuf, sizeof(acReadBuf), &ulBytesRead, NULL);

	if (FT_FAILED(ftStatus))
	{
		FT_Close(ftHandle);
		printf("FT_ReadPipe FALSE\n");
	}
	else
	{
		printf("FT_ReadPipe OK\n");
	}
	
	printf("ulBytesRead : %d\n", ulBytesRead);

	printf("Merge the Read Data\n");
	for (ULONG i = 0; i < ReadBUFFER_SIZE / 2; i++)
	{
		Read_Result[i] = acReadBuf[2*i+1] * 256 + acReadBuf[2*i];
		//printf("Read_Result[%d] : %d\n", i, Read_Result[i]);
	}
	
	
	// Close device handle 
	FT_Close(ftHandle);	
	system("pause");
	return 0;
}

