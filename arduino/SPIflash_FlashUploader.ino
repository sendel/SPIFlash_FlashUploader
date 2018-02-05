// SPIflash_FlashUploader 
// Copyright (C)2015 Rinky-Dink Electronics, Henning Karlsen. All right reserved
// web: http://www.RinkyDinkElectronics.com/
//
// This program must be running on your development
// board if you are trying to upload data directly
// from the "FlashUploader" PC application.
//
// Please note that uploading over a serial link 
// have been unstable during testing, and should 
// only be used if you cannot upload data via a
// SD card using the SPIflash_Restore sketch.
//
// It also seems that using software SPI to 
// communicate with the flash chip makes it even
// more ustable. The flash chip should therefore
// be connected to the hardware SPI port on your
// development board.
//
// Also note that serial transfer of data is SLOW.
//

#include <SPIflash.h>

// Software SPI
// Remember to set the correct pins for your development board
// Parameter order: SI/MOSI, SO/MISO, SCK/SCLK, CE/SS
//SPIflash myFlash(5, 6, 7, 4);

// Hardware SPI
// Remember to set the correct pin for your development board
// Parameter order: CE/SS
SPIflash myFlash(7);

#define RESPONSE_ACK  "ACK"
#define RESPONSE_NAK  "NAK"

char input;
char MagicString[] = "FlUl0002";
uint8_t check1, check2, check;
long page;
char b64buf[344];
const char b64[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

void sendBuffer()
{
  for (int c=0; c<344; c++)
  {
    Serial.write(b64buf[c]);
  }
}


uint8_t  Crc8(uint8_t  *pcBlock, unsigned long len)
{
    uint8_t  crc = 0xFF;
    unsigned long i;

    while (len--)
    {
        crc ^= *pcBlock++;

        for (i = 0; i < 8; i++)
            crc = crc & 0x80 ? (crc << 1) ^ 0x31 : crc << 1;
    }

    return crc;
}

void base64encode()
{
  int fc = 0, tc = 0;
  
  while (fc<255)
  {
    b64buf[tc]   = b64[(myFlash.buffer[fc] & 0xfc) >> 2];
    b64buf[tc+1] = b64[((myFlash.buffer[fc] & 0x03) << 4) + ((myFlash.buffer[fc+1] & 0xf0) >> 4)];
    b64buf[tc+2] = b64[((myFlash.buffer[fc+1] & 0x0f) << 2) + ((myFlash.buffer[fc+2] & 0xc0) >> 6)];
    b64buf[tc+3] = b64[(myFlash.buffer[fc+2] & 0x3f)];
    fc += 3;
    tc += 4;
  }
  b64buf[tc]   = b64[(myFlash.buffer[fc] & 0xfc) >> 2];
  b64buf[tc+1] = b64[((myFlash.buffer[fc] & 0x03) << 4) + ((myFlash.buffer[fc+1] & 0xf0) >> 4)];
  b64buf[tc+2] = '=';
  b64buf[tc+3] = '=';
}


void setup()
{
  Serial.begin(57600);
  myFlash.begin();
}

void loop()
{
    long srd = 0 , d = 0;
    uint8_t vbuf[32];
    
  if (myFlash.ID_device!=0)
  {
    Serial.print(MagicString);
    while (1)
    {
      if (Serial.available())
      {
        input=Serial.read();
        switch (input)
        {
          case 'I':
            Serial.print(myFlash.ID_manufacturer, HEX);
            Serial.print(myFlash.ID_type, HEX);
            Serial.print(myFlash.ID_device, HEX);
            break;
          case 'C':
            myFlash.eraseChip();
            Serial.print(RESPONSE_ACK);
            break;
          case 'U': // Upload page
            srd = 0;
            while (Serial.available()<4) {};
            Serial.readBytes(vbuf, 4);
            page=(long(vbuf[3])<<24)+(long(vbuf[2])<<16)+(long(vbuf[1])<<8)+vbuf[0];
            Serial.print(RESPONSE_ACK);
            while(srd<256){
               
              if (Serial.available() > 0){
                 d = Serial.readBytes(vbuf, 32);
                  memcpy(&myFlash.buffer[srd], vbuf, d);
                  srd += d;
              }
            }
            Serial.print(RESPONSE_ACK);
            while (!Serial.available()) {};
            check1 = Serial.read();    

            check = Crc8(myFlash.buffer,256);

            if (check  == check1)
            {
              myFlash.writePage(page);
              delay(100);
              Serial.print(RESPONSE_ACK);
            }
            else
            {
              Serial.print(RESPONSE_NAK);
            }
            break;
          case 'D': // Download page
            while (Serial.available()<4) {};
            Serial.readBytes(vbuf, 4);
            page=(long(vbuf[3])<<24)+(long(vbuf[2])<<16)+(long(vbuf[1])<<8)+vbuf[0];
            delay(50);
            Serial.print(RESPONSE_ACK);
            while (!Serial.available()) {};
            Serial.read();    
            myFlash.readPage(page);
            base64encode();
            delay(10);
            sendBuffer();
            break;
        }
      }
    }
  }
}

