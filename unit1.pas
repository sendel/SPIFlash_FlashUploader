unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, Buttons,
  StdCtrls, IdCoderMIME, LazSerial, base64, crt;

type

  { TForm1 }

  TForm1 = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    IdDecoderMIME1: TIdDecoderMIME;
    LazSerial1: TLazSerial;
    Memo1: TMemo;
    OpenDialog1: TOpenDialog;
    StaticText1: TStaticText;
    StaticText2: TStaticText;
    StaticText3: TStaticText;
    StaticText4: TStaticText;
    procedure BitBtn1Click(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    procedure BitBtn3Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure LazSerial1RxData(Sender: TObject);
  private
    { private declarations }
     LStrings: TStringList;
     LastCRC: Byte;
     AR_Msg:string;
     AR_Status: Integer;
     TotalPages: Integer;
     CurrentPage: Integer;
  public
    { public declarations }
    procedure getId();
    procedure Write_Page();
    //function crc8(pcBlock: PByte; len: Integer):Byte;
    function crc8(Buffer:PByte;len:Cardinal):Byte;
  end;

var
  Form1: TForm1;


implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.BitBtn1Click(Sender: TObject);
var
  i:Integer;
begin
  if OpenDialog1.Execute then
  begin
        StaticText1.Caption:=OpenDialog1.FileName;
        LStrings := TStringList.Create;
        LStrings.Loadfromfile(OpenDialog1.FileName);
        Memo1.Clear;
        for i:=0 to 3 do
        begin
           Memo1.Append(LStrings.Strings[i]);
        end;
        Memo1.Append(LStrings.Strings[4]);
        TotalPages := StrToInt(LStrings.Strings[4]);
        BitBtn2.Enabled:=true;
  end;
end;

{function TForm1.crc8(pcBlock: PByte; len: Integer):Byte;
var crc:Byte;
    i:Byte;
    j:integer;
begin
    crc := $FF;
    j:=0;
    while len>0 do
    begin
        dec(len);
        crc:= crc xor pcBlock[j];
        Inc(j);
        for i := 0 to  7 do
        begin

            if (crc and $80)<>0 then crc:= (crc shl 1) xor $31 else crc := crc shl 1;
       end;
    end;

    result:=crc;
end;}

function TForm1.crc8(Buffer:PByte;len:Cardinal):Byte;
var
  i,j: Integer;
begin
Result:=$FF;
for i:=0 to len-1 do begin
  Result:=Result xor buffer[i];
  for j:=0 to 7 do begin
    if (Result and $80)<>0 then Result:=(Result shl 1) xor $31
    else Result:=Result shl 1;
    end;
  end;
//Result:=Result and $ff;
end;


procedure TForm1.getId();
begin
     LazSerial1.WriteData('I');
end;

procedure TForm1.Write_Page();
var bs,ds:string;
    crc, i:Integer;
    Decoder   : TBase64DecodingStream;
    EncodedStream : TStringStream;
    ar : array[0..255] of Byte;
    PT:  ^Byte;
    s: string;
begin

    bs := LStrings.Strings[CurrentPage + 5];
    try
    //ds:= IdDecoderMIME1.DecodeString(bs);
    EncodedStream := TStringStream.Create(bs);
    Decoder:= TBase64DecodingStream.Create(EncodedStream);
    Decoder.Read(ar,256);

    crc:=crc8(ar,256);

    for i:=0 to 31 do
    begin
      s:=s+IntToHex(ar[i],2)+' ';
    end;
     Memo1.Append(s);
    PT :=  ar;
    for i:= 0 to 7 do
    begin

        LazSerial1.WriteBuffer(PT^,32);
        PT:=PT+32;
        Delay(10);
    end;

    LastCRC := crc;


    except
         Memo1.Append('Error wile write page');
    end;


end;


procedure TForm1.BitBtn2Click(Sender: TObject);
begin
       //sendtoserial();
  AR_Status:=0;
  CurrentPage:=0;
  LazSerial1.Open;
  StaticText2.Caption:='Connection...';
  Memo1.Append(StaticText2.Caption);
end;

procedure TForm1.BitBtn3Click(Sender: TObject);
begin

end;

procedure TForm1.FormCreate(Sender: TObject);
begin

end;

procedure TForm1.LazSerial1RxData(Sender: TObject);
var
    PT: ^Integer;
    PB: ^Byte;
begin
    AR_Msg:=AR_Msg + LazSerial1.ReadData;
    Memo1.Append('l: ' +IntToStr(length(AR_Msg)) + ' d:' + AR_Msg );

    if ((AR_Status = 0) and (CompareStr(AR_Msg,'FlUl0002')=0)) then
    begin
        StaticText2.Caption:='Connected';
        Memo1.Append(StaticText2.Caption);
        AR_Status:=1;
        AR_Msg:= '';
        getId();
    end;

    if (AR_Status = 1) and (length(AR_Msg) = 6)  then
    begin
        writeln(AR_Msg);
        StaticText2.Caption:='Chip Id: ' + AR_Msg;
        Memo1.Append(StaticText2.Caption);
        AR_Status:=9;
        AR_Msg:= '';
        Delay(50);
        LazSerial1.WriteData('C');

    end;

    if (AR_Status = 9) and (AR_Msg = 'ACK') then
    begin
        StaticText2.Caption:='Erased chip, send page num' + IntToStr(CurrentPage);
        Memo1.Append(StaticText2.Caption);
        AR_Status:=2;
        AR_Msg:= '';
        Delay(50);
        LazSerial1.WriteData('U');
        Delay(50);
        PT := @CurrentPage;
        LazSerial1.WriteBuffer(PT^,SizeOf(Integer)); //write page num;

    end;

    //write page num
    if (AR_Status = 2) and (AR_Msg = 'ACK') then
    begin
        StaticText2.Caption:='Page num ' + IntToStr(CurrentPage) + ' sended, sending data';
        Memo1.Append(StaticText2.Caption);
        AR_Status:=3;
        AR_Msg:= '';
        Delay(50);
        Write_Page();

    end;

    //write CRC
    if (AR_Status = 3) and (AR_Msg = 'ACK') then
    begin
        StaticText2.Caption:='Send for ' + IntToStr(CurrentPage) + ' crc ' + IntToHex(LastCRC, 8);
        Memo1.Append(StaticText2.Caption);


        AR_Status:=5;
        AR_Msg:= '';
        Delay(50);
        //LastCRC := $deadbeef; //recive eeaa00ff
        PB := @LastCRC;

        LazSerial1.WriteBuffer(PB^,SizeOf(Byte)); //write page crc;

    end;

    //write CRC
    if (AR_Status = 5) and (AR_Msg = 'ACK') then
    begin
        AR_Msg:= '';
        StaticText2.Caption:='Page num ' + IntToStr(CurrentPage) + ' writed';
        Memo1.Append(StaticText2.Caption);
        if CurrentPage =  (TotalPages-1) then
        begin
            AR_Status := 0;  //end
            TotalPages := 0;
            StaticText2.Caption:='Finished';
            Memo1.Append(StaticText2.Caption);
        end
        else
        begin
            Inc(CurrentPage);
            AR_Status:=2; //while OK
            Delay(50);
            LazSerial1.WriteData('U');
            Delay(50);
            PT := @CurrentPage;
            LazSerial1.WriteBuffer(PT^,SizeOf(Integer)); //write page num;
        end;

    end;


    if (AR_Status = 5) and (AR_Msg = 'NAK') then
    begin
        StaticText2.Caption:='Error on status ' + IntToStr(AR_Status);
        Memo1.Append(StaticText2.Caption);
        //try send page again
        AR_Status:=2; //while OK
        Delay(10);
        LazSerial1.WriteData('U');
        Delay(10);
        PT := @CurrentPage;
        LazSerial1.WriteBuffer(PT^,SizeOf(Integer)); //write page num;
    end;

end;

end.

