program visor_mp25;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  main,
  tachartlazaruspkg,
  LazSerialPort;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title := 'By Alberto Caro';
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TFormPrincipal, FormPrincipal);
  Application.Run;
end.
