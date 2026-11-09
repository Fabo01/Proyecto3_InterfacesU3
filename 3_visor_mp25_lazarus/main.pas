unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Buttons, ExtCtrls, TAGraph, TASeries, TATypes, TAChartUtils,
  LazSerial, WinSock2;

type

  { TFormPrincipal }

  TFormPrincipal = class(TForm)
    ChkConectarSerial: TCheckBox;
    ChkEnviarTCP: TCheckBox;
    LblEstado: TLabel;
    BtnSave: TBitBtn;
    BtnOnOff: TBitBtn;
    GraficoMP25: TChart;
    SerieMP25: TLineSeries;
    BtnClickFondo: TBitBtn;
    PuertoSerial: TLazSerial;
    TimerReconexion: TTimer;

    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure ChkConectarSerialChange(Sender: TObject);
    procedure BtnOnOffClick(Sender: TObject);
    procedure BtnSaveClick(Sender: TObject);
    procedure BtnClickFondoClick(Sender: TObject);
    procedure PuertoSerialRxData(Sender: TObject);
    procedure TimerReconexionTimer(Sender: TObject);

  private
    imagenes_fondo: array[1..6] of TPicture;
    bitmap_fondo_cache: TBitmap;
    indice_fondo: Integer;
    historial_mp25: array[0..29] of Integer;
    grilla_activa: Boolean;
    datos_winsock: TWSAData;
    wsa_inicializado: Boolean;

    function ObtenerCarpetaBase: String;
    procedure DibujarFondoGrafico(ASender: TChart; ACanvas: TCanvas; const ARect: TRect);
    function EnviarMP25PorTCP(valor_mp25: Integer): Boolean;
    procedure ActualizarGrafico;

  public

  end;

var
  FormPrincipal: TFormPrincipal;

implementation

{$R *.lfm}

{ TFormPrincipal }

function TFormPrincipal.ObtenerCarpetaBase: String;
var
  carpeta_base: String;
begin
  // Obtenemos la ruta del ejecutable de forma relativa y dinamica
  carpeta_base := ExtractFilePath(ParamStr(0));
  if carpeta_base = '' then
    carpeta_base := ExtractFilePath(Application.ExeName);
  Result := IncludeTrailingPathDelimiter(carpeta_base);
end;

procedure TFormPrincipal.FormCreate(Sender: TObject);
var
  carpeta_base, ruta_img: String;
  i, j: Integer;
  imagen_icono: TPicture;
begin
  carpeta_base := ObtenerCarpetaBase;

  // Inicializamos el arreglo de muestras en cero
  for j := 0 to 29 do
    historial_mp25[j] := 0;

  // Cargamos las imagenes de fondo para alternarlas con el boton de paleta
  for i := 1 to 6 do
  begin
    imagenes_fondo[i] := TPicture.Create;
    ruta_img := carpeta_base + 'img' + IntToStr(i) + '.png';
    if FileExists(ruta_img) then
      imagenes_fondo[i].LoadFromFile(ruta_img);
  end;

  indice_fondo := 6;
  bitmap_fondo_cache := TBitmap.Create;
  GraficoMP25.OnAfterDrawBackWall := @DibujarFondoGrafico;

  // Cargamos los iconos de los botones y de la ventana desde la carpeta del proyecto
  imagen_icono := TPicture.Create;
  try
    if FileExists(carpeta_base + 'camara.png') then
    begin
      imagen_icono.LoadFromFile(carpeta_base + 'camara.png');
      BtnSave.Glyph.Assign(imagen_icono.Bitmap);
    end;

    if FileExists(carpeta_base + 'pale.png') then
    begin
      imagen_icono.LoadFromFile(carpeta_base + 'pale.png');
      BtnClickFondo.Glyph.Assign(imagen_icono.Bitmap);
    end;

    if FileExists(carpeta_base + 'f02.bmp') then
    begin
      imagen_icono.LoadFromFile(carpeta_base + 'f02.bmp');
      BtnOnOff.Glyph.Assign(imagen_icono.Bitmap);
    end;

    if FileExists(carpeta_base + 'sms2.bmp') then
    begin
      imagen_icono.LoadFromFile(carpeta_base + 'sms2.bmp');
      Self.Icon.Assign(imagen_icono.Bitmap);
    end;
  finally
    imagen_icono.Free;
  end;

  // Dejamos el boton de paleta al frente para que no lo tape el grafico
  BtnClickFondo.BringToFront;

  // Configuramos el estado inicial de la grilla
  grilla_activa := True;

  // Configuramos el titulo y los ejes del grafico
  GraficoMP25.Title.Text.Text := 'Material Particulado 2.5 um';
  GraficoMP25.Title.Visible := True;
  GraficoMP25.Title.Font.Style := [fsBold];
  GraficoMP25.Title.Font.Size := 11;
  GraficoMP25.Title.Font.Color := clBlack;

  GraficoMP25.BottomAxis.Title.Caption := 'Sampling MP 2.5um';
  GraficoMP25.BottomAxis.Title.Visible := True;
  GraficoMP25.BottomAxis.Title.LabelFont.Style := [fsBold];
  GraficoMP25.BottomAxis.Intervals.NiceSteps := '1';
  GraficoMP25.BottomAxis.Intervals.MinLength := 10;

  GraficoMP25.LeftAxis.Title.Caption := '[ug/m3]';
  GraficoMP25.LeftAxis.Title.Visible := True;
  GraficoMP25.LeftAxis.Title.LabelFont.Orientation := 900;
  GraficoMP25.LeftAxis.Title.LabelFont.Style := [fsBold];

  // Definimos los rangos de visualizacion (0 a 200 ug/m3 y 0 a 29 muestras)
  GraficoMP25.Extent.YMin := 0;
  GraficoMP25.Extent.YMax := 200;
  GraficoMP25.Extent.UseYMin := True;
  GraficoMP25.Extent.UseYMax := True;

  GraficoMP25.Extent.XMin := 0;
  GraficoMP25.Extent.XMax := 29;
  GraficoMP25.Extent.UseXMin := True;
  GraficoMP25.Extent.UseXMax := True;

  // Configuramos la grilla punteada
  GraficoMP25.LeftAxis.Grid.Visible := grilla_activa;
  GraficoMP25.LeftAxis.Grid.Style := psDot;
  GraficoMP25.LeftAxis.Grid.Color := clGray;

  GraficoMP25.BottomAxis.Grid.Visible := grilla_activa;
  GraficoMP25.BottomAxis.Grid.Style := psDot;
  GraficoMP25.BottomAxis.Grid.Color := clGray;

  GraficoMP25.Legend.Visible := True;
  GraficoMP25.Legend.Frame.Visible := True;

  // Estilo de la serie: linea roja con marcadores y etiquetas sobre los puntos
  SerieMP25.Title := 'MP 2.5 um';
  SerieMP25.SeriesColor := clRed;
  SerieMP25.LinePen.Color := clRed;
  SerieMP25.LinePen.Width := 2;
  SerieMP25.ShowPoints := True;

  SerieMP25.Pointer.Visible := True;
  SerieMP25.Pointer.Style := psRectangle;
  SerieMP25.Pointer.Brush.Color := $00D89838;
  SerieMP25.Pointer.Pen.Color := clNavy;
  SerieMP25.Pointer.HorizSize := 4;
  SerieMP25.Pointer.VertSize := 4;

  SerieMP25.Marks.Style := smsValue;
  SerieMP25.Marks.Visible := True;
  SerieMP25.Marks.Format := '%0:.9g';
  SerieMP25.Marks.LabelBrush.Color := $00F0F8FF;
  SerieMP25.Marks.LabelBrush.Style := bsSolid;
  SerieMP25.Marks.LabelFont.Color := clBlack;
  SerieMP25.Marks.Frame.Visible := True;
  SerieMP25.Marks.Frame.Color := clBlack;
  SerieMP25.Marks.LinkPen.Visible := True;
  SerieMP25.Marks.Distance := 10;
  SerieMP25.Marks.Clipped := False;

  // Mostramos el grafico inicial
  ActualizarGrafico;

  // Inicializamos WinSock para la comunicacion TCP
  wsa_inicializado := (WSAStartup($0202, datos_winsock) = 0);

  // Intentamos abrir el puerto serial en COM2
  try
    PuertoSerial.Device := 'COM2';
    PuertoSerial.BaudRate := br__9600;
    PuertoSerial.Open;
    LblEstado.Caption := 'COM2: Conectado | Esperando datos... | TCP: Listo';
  except
    on E: Exception do
      LblEstado.Caption := 'COM2: Esperando conexion VSPE... | TCP: Listo';
  end;

  TimerReconexion.Enabled := True;
end;

procedure TFormPrincipal.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  i: Integer;
begin
  TimerReconexion.Enabled := False;

  if PuertoSerial.Active then
  begin
    try
      PuertoSerial.Close;
    except
    end;
  end;

  if wsa_inicializado then
  begin
    WSACleanup;
    wsa_inicializado := False;
  end;

  FreeAndNil(bitmap_fondo_cache);
  for i := 1 to 6 do
    FreeAndNil(imagenes_fondo[i]);
end;

procedure TFormPrincipal.DibujarFondoGrafico(ASender: TChart; ACanvas: TCanvas; const ARect: TRect);
var
  ancho, alto: Integer;
begin
  if (indice_fondo < 1) or (indice_fondo > 6) then
    Exit;
  if not Assigned(imagenes_fondo[indice_fondo]) or (imagenes_fondo[indice_fondo].Width = 0) then
    Exit;

  ancho := ARect.Right - ARect.Left;
  alto := ARect.Bottom - ARect.Top;
  if (ancho <= 0) or (alto <= 0) then
    Exit;

  // Redimensionamos la imagen solo cuando cambia el tamano de la ventana
  if (bitmap_fondo_cache.Width <> ancho) or (bitmap_fondo_cache.Height <> alto) then
  begin
    bitmap_fondo_cache.SetSize(ancho, alto);
    bitmap_fondo_cache.Canvas.StretchDraw(Rect(0, 0, ancho, alto), imagenes_fondo[indice_fondo].Graphic);
  end;

  ACanvas.Draw(ARect.Left, ARect.Top, bitmap_fondo_cache);
end;

procedure TFormPrincipal.ActualizarGrafico;
var
  j: Integer;
begin
  // Redibujamos los 30 puntos en el grafico
  SerieMP25.BeginUpdate;
  try
    SerieMP25.Clear;
    for j := 0 to 29 do
      SerieMP25.AddXY(j, historial_mp25[j]);
  finally
    SerieMP25.EndUpdate;
  end;
end;

procedure TFormPrincipal.BtnClickFondoClick(Sender: TObject);
begin
  // Cambiamos al siguiente fondo disponible de 1 a 6
  if indice_fondo = 6 then
    indice_fondo := 1
  else
    Inc(indice_fondo);

  bitmap_fondo_cache.SetSize(0, 0);
  GraficoMP25.Invalidate;
  BtnClickFondo.BringToFront;
end;

procedure TFormPrincipal.BtnOnOffClick(Sender: TObject);
begin
  // Alternamos la visibilidad de la grilla
  grilla_activa := not grilla_activa;
  GraficoMP25.LeftAxis.Grid.Visible := grilla_activa;
  GraficoMP25.BottomAxis.Grid.Visible := grilla_activa;
  GraficoMP25.Invalidate;
  BtnClickFondo.BringToFront;
end;

procedure TFormPrincipal.BtnSaveClick(Sender: TObject);
var
  carpeta_base, carpeta_capturas, ruta_captura, ruta_historial: String;
begin
  // Guardamos la captura del grafico en formato PNG
  carpeta_base := ObtenerCarpetaBase;
  carpeta_capturas := carpeta_base + 'capturas' + DirectorySeparator;
  ForceDirectories(carpeta_capturas);

  ruta_captura := carpeta_base + 'captura.png';
  ruta_historial := carpeta_capturas + 'captura_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.png';

  try
    GraficoMP25.SaveToFile(TPortableNetworkGraphic, ruta_captura);
    GraficoMP25.SaveToFile(TPortableNetworkGraphic, ruta_historial);
    LblEstado.Caption := 'Captura guardada: captura.png';
  except
    on E: Exception do
      LblEstado.Caption := 'Error al guardar captura: ' + E.Message;
  end;
end;

procedure TFormPrincipal.ChkConectarSerialChange(Sender: TObject);
begin
  if not ChkConectarSerial.Checked then
  begin
    if PuertoSerial.Active then
    begin
      try
        PuertoSerial.Close;
      except
      end;
    end;
    LblEstado.Caption := 'COM2: Desconectado por usuario';
  end
  else
  begin
    try
      PuertoSerial.Device := 'COM2';
      PuertoSerial.BaudRate := br__9600;
      PuertoSerial.Open;
      LblEstado.Caption := 'COM2: Conectado | Esperando datos...';
    except
      on E: Exception do
        LblEstado.Caption := 'COM2: Error al conectar (' + E.Message + ')';
    end;
  end;
end;

procedure TFormPrincipal.TimerReconexionTimer(Sender: TObject);
begin
  // Si el puerto esta marcado para conectar pero no esta activo, reintentamos
  if ChkConectarSerial.Checked and (not PuertoSerial.Active) then
  begin
    try
      PuertoSerial.Device := 'COM2';
      PuertoSerial.BaudRate := br__9600;
      PuertoSerial.Open;
      LblEstado.Caption := 'COM2: Conectado | Esperando datos...';
    except
      LblEstado.Caption := 'COM2: Esperando conexion VSPE...';
    end;
  end;
end;

function TFormPrincipal.EnviarMP25PorTCP(valor_mp25: Integer): Boolean;
var
  socket_cliente: TSocket;
  direccion_servidor: TSockAddrIn;
  modo_no_bloqueante: u_long;
  conjunto_escritura, conjunto_error: TFDSet;
  tiempo_espera: TTimeVal;
  resultado_select: Longint;
  mensaje_envio: AnsiString;
begin
  Result := False;
  if not wsa_inicializado then
    Exit;

  socket_cliente := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if socket_cliente = INVALID_SOCKET then
    Exit;

  try
    // Configuramos el socket en modo no bloqueante para no congelar la ventana
    modo_no_bloqueante := 1;
    ioctlsocket(socket_cliente, Longint(FIONBIO), modo_no_bloqueante);

    FillChar(direccion_servidor, SizeOf(direccion_servidor), 0);
    direccion_servidor.sin_family := AF_INET;
    direccion_servidor.sin_port := htons(9000);
    direccion_servidor.sin_addr.s_addr := inet_addr('127.0.0.1');

    connect(socket_cliente, PSockAddr(@direccion_servidor), SizeOf(direccion_servidor));

    FD_ZERO(conjunto_escritura);
    FD_SET(socket_cliente, conjunto_escritura);
    FD_ZERO(conjunto_error);
    FD_SET(socket_cliente, conjunto_error);

    tiempo_espera.tv_sec := 0;
    tiempo_espera.tv_usec := 80000; // 80 milisegundos

    resultado_select := select(0, nil, @conjunto_escritura, @conjunto_error, @tiempo_espera);
    if (resultado_select > 0) and FD_ISSET(socket_cliente, conjunto_escritura) and (not FD_ISSET(socket_cliente, conjunto_error)) then
    begin
      mensaje_envio := IntToStr(valor_mp25) + #10;
      if send(socket_cliente, PChar(mensaje_envio)^, Length(mensaje_envio), 0) <> SOCKET_ERROR then
        Result := True;
    end;
  finally
    closesocket(socket_cliente);
  end;
end;

procedure TFormPrincipal.PuertoSerialRxData(Sender: TObject);
var
  texto_serial: String;
  lista_lineas: TStringList;
  linea, texto_tcp: String;
  i, j, valor_mp25: Integer;
  envio_exitoso: Boolean;
begin
  // Leemos los datos entrantes del puerto serial
  texto_serial := Trim(PuertoSerial.ReadData);
  if texto_serial = '' then
    Exit;

  lista_lineas := TStringList.Create;
  try
    lista_lineas.Text := texto_serial;
    for i := 0 to lista_lineas.Count - 1 do
    begin
      linea := Trim(lista_lineas[i]);
      if linea = '' then
        Continue;

      if TryStrToInt(linea, valor_mp25) then
      begin
        // Desplazamos las 30 muestras a la izquierda para agregar la nueva
        for j := 0 to 28 do
          historial_mp25[j] := historial_mp25[j + 1];
        historial_mp25[29] := valor_mp25;

        ActualizarGrafico;

        // Enviamos el dato al servidor TCP si la casilla esta marcada
        if ChkEnviarTCP.Checked then
        begin
          envio_exitoso := EnviarMP25PorTCP(valor_mp25);
          if envio_exitoso then
            texto_tcp := 'TCP: OK'
          else
            texto_tcp := 'TCP: Sin Servidor (Puerto 9000)';
        end
        else
          texto_tcp := 'TCP: Desactivado';

        LblEstado.Caption := 'COM2: Conectado | Ultimo MP2.5: ' + IntToStr(valor_mp25) + ' ug/m3 | ' + texto_tcp;
      end;
    end;
  finally
    lista_lineas.Free;
  end;
end;

end.
