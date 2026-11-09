program server_tcp;

{$mode objfpc}{$H+}
{$APPTYPE CONSOLE}

uses
  Classes,
  SysUtils,
  WinSock2,
  sqlite3conn,
  sqldb;

const
  PUERTO_TCP = 9000;

var
  ruta_bd: String;

function CrearPalabra(byte_bajo, byte_alto: Byte): Word; inline;
begin
  Result := Word(byte_bajo) or (Word(byte_alto) shl 8);
end;

function ExtraerNumero(const texto: String; out valor: Integer): Boolean;
var
  i, j: Integer;
  texto_numero: String;
begin
  Result := False;
  valor := 0;
  if TryStrToInt(Trim(texto), valor) then
  begin
    Result := True;
    Exit;
  end;

  // Si viniera con texto adicional o etiquetas
  i := Pos('mp25', LowerCase(texto));
  if i = 0 then
    i := 1
  else
    i := i + 4;

  while (i <= Length(texto)) and not (texto[i] in ['0'..'9', '-']) do
    Inc(i);

  if i <= Length(texto) then
  begin
    j := i;
    if texto[j] = '-' then
      Inc(j);
    while (j <= Length(texto)) and (texto[j] in ['0'..'9']) do
      Inc(j);

    texto_numero := Copy(texto, i, j - i);
    Result := TryStrToInt(texto_numero, valor);
  end;
end;

procedure IniciarBaseDatos;
var
  conexion_bd: TSQLite3Connection;
  transaccion_bd: TSQLTransaction;
begin
  conexion_bd := TSQLite3Connection.Create(nil);
  transaccion_bd := TSQLTransaction.Create(nil);
  try
    try
      conexion_bd.DatabaseName := ruta_bd;
      conexion_bd.Transaction := transaccion_bd;
      transaccion_bd.DataBase := conexion_bd;
      transaccion_bd.Options := [stoUseImplicit];

      conexion_bd.Open;
      transaccion_bd.StartTransaction;

      // Optimizamos SQLite para acceso concurrente con el visor y Flask
      conexion_bd.ExecuteDirect('PRAGMA journal_mode=WAL;');
      conexion_bd.ExecuteDirect('PRAGMA synchronous=NORMAL;');
      conexion_bd.ExecuteDirect('CREATE TABLE IF NOT EXISTS Aire (' +
                                'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
                                'fecha TEXT NOT NULL, ' +
                                'hora TEXT NOT NULL, ' +
                                'mp25 INTEGER NOT NULL);');

      transaccion_bd.Commit;
    except
      on E: Exception do
      begin
        if transaccion_bd.Active then
          transaccion_bd.Rollback;
        WriteLn('Error al inicializar SQLite: ' + E.Message);
        raise;
      end;
    end;
  finally
    transaccion_bd.Free;
    conexion_bd.Free;
  end;
end;

function GuardarEnSQLite(const fecha_texto, hora_texto: String; valor_mp25: Integer): Int64;
var
  conexion_bd: TSQLite3Connection;
  transaccion_bd: TSQLTransaction;
  consulta_sql: TSQLQuery;
begin
  Result := -1;
  conexion_bd := TSQLite3Connection.Create(nil);
  transaccion_bd := TSQLTransaction.Create(nil);
  consulta_sql := TSQLQuery.Create(nil);
  try
    try
      conexion_bd.DatabaseName := ruta_bd;
      conexion_bd.Transaction := transaccion_bd;
      transaccion_bd.DataBase := conexion_bd;
      consulta_sql.DataBase := conexion_bd;
      consulta_sql.Transaction := transaccion_bd;

      conexion_bd.Open;
      transaccion_bd.StartTransaction;

      // Insertamos la muestra en la tabla Aire
      consulta_sql.SQL.Text := 'INSERT INTO Aire (fecha, hora, mp25) VALUES (:f, :h, :m);';
      consulta_sql.ParamByName('f').AsString := fecha_texto;
      consulta_sql.ParamByName('h').AsString := hora_texto;
      consulta_sql.ParamByName('m').AsInteger := valor_mp25;
      consulta_sql.ExecSQL;

      // Obtenemos el ID autoincremental generado
      consulta_sql.Close;
      consulta_sql.SQL.Text := 'SELECT last_insert_rowid() AS ultimo_id;';
      consulta_sql.Open;
      if not consulta_sql.EOF then
        Result := consulta_sql.FieldByName('ultimo_id').AsLargeInt;
      consulta_sql.Close;

      transaccion_bd.Commit;
    except
      on E: Exception do
      begin
        if transaccion_bd.Active then
          transaccion_bd.Rollback;
        WriteLn(Format('Error al guardar registro en SQLite: %s', [E.Message]));
      end;
    end;
  finally
    consulta_sql.Free;
    transaccion_bd.Free;
    conexion_bd.Free;
  end;
end;

procedure ProcesarLinea(const texto_recibido: String);
var
  limpio: String;
  valor_mp25: Integer;
  fecha_actual, hora_actual: String;
  id_insertado: Int64;
begin
  limpio := Trim(texto_recibido);
  if limpio = '' then
    Exit;

  if not ExtraerNumero(limpio, valor_mp25) then
  begin
    WriteLn('Trama no valida recibida: "' + limpio + '"');
    Exit;
  end;

  fecha_actual := FormatDateTime('yyyy-mm-dd', Now);
  hora_actual := FormatDateTime('hh:nn:ss', Now);

  id_insertado := GuardarEnSQLite(fecha_actual, hora_actual, valor_mp25);

  WriteLn(Format('Registro #%d | Fecha: %s | Hora: %s | MP 2.5: %d ug/m3 (Guardado en Tabla Aire)',
    [id_insertado, fecha_actual, hora_actual, valor_mp25]));
end;

procedure EjecutarServidorTCP;
var
  datos_winsock: TWSAData;
  socket_servidor, socket_cliente: TSocket;
  direccion_servidor, direccion_cliente: TSockAddrIn;
  largo_direccion: LongInt;
  opcion_reusar: LongInt;
  buffer: array[0..2047] of Char;
  bytes_recibidos: LongInt;
  acumulador, linea: String;
  pos_salto: Integer;
begin
  // Inicializamos WinSock2
  if WSAStartup(CrearPalabra(2, 2), datos_winsock) <> 0 then
  begin
    WriteLn('Error al inicializar WinSock2.');
    Exit;
  end;

  try
    socket_servidor := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if socket_servidor = INVALID_SOCKET then
    begin
      WriteLn('No se pudo crear el socket TCP.');
      Exit;
    end;

    // Permitimos reusar la direccion de inmediato
    opcion_reusar := 1;
    setsockopt(socket_servidor, SOL_SOCKET, SO_REUSEADDR, @opcion_reusar, SizeOf(opcion_reusar));

    FillChar(direccion_servidor, SizeOf(direccion_servidor), 0);
    direccion_servidor.sin_family := AF_INET;
    direccion_servidor.sin_port := htons(PUERTO_TCP);
    direccion_servidor.sin_addr.s_addr := INADDR_ANY;

    if bind(socket_servidor, PSockAddr(@direccion_servidor), SizeOf(direccion_servidor)) = SOCKET_ERROR then
    begin
      WriteLn(Format('Fallo al enlazar en el puerto %d (bind error).', [PUERTO_TCP]));
      closesocket(socket_servidor);
      Exit;
    end;

    if listen(socket_servidor, 5) = SOCKET_ERROR then
    begin
      WriteLn('Fallo al poner el socket en escucha (listen error).');
      closesocket(socket_servidor);
      Exit;
    end;

    WriteLn('Servidor TCP Lazarus iniciado en el puerto 9000...');
    WriteLn('Base de datos SQLite lista en: ' + ruta_bd);

    while True do
    begin
      largo_direccion := SizeOf(direccion_cliente);
      socket_cliente := accept(socket_servidor, PSockAddr(@direccion_cliente), largo_direccion);
      if socket_cliente = INVALID_SOCKET then
        Continue;

      acumulador := '';
      while True do
      begin
        bytes_recibidos := recv(socket_cliente, buffer, SizeOf(buffer) - 1, 0);
        if bytes_recibidos <= 0 then
          Break;

        buffer[bytes_recibidos] := #0;
        acumulador := acumulador + Copy(buffer, 1, bytes_recibidos);

        repeat
          pos_salto := Pos(#10, acumulador);
          if pos_salto > 0 then
          begin
            linea := Copy(acumulador, 1, pos_salto - 1);
            Delete(acumulador, 1, pos_salto);
            ProcesarLinea(linea);
          end;
        until pos_salto = 0;
      end;

      // Si quedo un valor pendiente sin salto de linea
      if Trim(acumulador) <> '' then
      begin
        ProcesarLinea(acumulador);
        acumulador := '';
      end;

      closesocket(socket_cliente);
    end;

  finally
    closesocket(socket_servidor);
    WSACleanup;
  end;
end;

begin
  ruta_bd := ExtractFilePath(ParamStr(0)) + 'aire.db';
  try
    IniciarBaseDatos;
    EjecutarServidorTCP;
  except
    on E: Exception do
      WriteLn('Excepcion en el servidor: ' + E.Message);
  end;
end.
