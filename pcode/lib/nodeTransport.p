/*------------------------------------------------------------------------
    File        : lib/nodeTransport.p
    Purpose     : pass json to node, get response

    Author(s)   : Hustlethroat
    Created     : Tue Oct 21 16:37:12 EEST 2014
  ----------------------------------------------------------------------*/
  
BLOCK-LEVEL ON ERROR UNDO, THROW.

/* ***************************  Definitions  ************************** */

USING lib.MemoryPointer.

DEFINE INPUT  PARAMETER oJsonObject AS JsonObject NO-UNDO.
DEFINE OUTPUT PARAMETER lcOut       AS LONGCHAR   NO-UNDO.

DEFINE VARIABLE mData        AS MEMPTR    NO-UNDO.

/* globals for node read proc */
DEFINE VARIABLE hNodeServer  AS HANDLE        NO-UNDO.
DEFINE VARIABLE lResponseEnd AS LOGICAL       NO-UNDO.
DEFINE VARIABLE oMemPtr      AS MemoryPointer NO-UNDO.
DEFINE VARIABLE mNodeResp    AS MEMPTR        NO-UNDO.

/* hardcoded config values */
DEFINE VARIABLE cConnStr     AS CHARACTER     NO-UNDO INITIAL "-H localhost -S 33120".

/* ***************************  Functions  **************************** */

/* construct output memptr for node connection from json */
FUNCTION prepareData MEMPTR( jsData AS JsonObject ):
    DEFINE VARIABLE iLength AS INTEGER NO-UNDO.
    DEFINE VARIABLE mOut    AS MEMPTR  NO-UNDO.
    DEFINE VARIABLE mJson   AS MEMPTR  NO-UNDO.
    
    msg("dbg", "prepare data for node").
    oJsonObject:WRITE(mJson, TRUE, "UTF-8").
    iLength = GET-SIZE(mJson).
    
    SET-SIZE(mOut) = 0.
    SET-SIZE(mOut) = iLength + 5.
    PUT-BYTES (mOut, 1) = mJson.
    PUT-STRING(mOut , iLength) = "~{~{E~}~}".
    iLength = GET-SIZE(mOut) - 1.
    
    RETURN mOut.
END FUNCTION.


/* connect node and stuff (needs size of data) */
FUNCTION prepareConnection LOGICAL (iLength AS INTEGER):
  DEFINE VARIABLE cConnStr    AS CHARACTER NO-UNDO.
  DEFINE VARIABLE lStatus     AS LOGICAL   NO-UNDO.
  
  CREATE SOCKET hNodeServer.
  lStatus = hNodeServer:CONNECT(cConnStr) NO-ERROR.
  IF lStatus = FALSE THEN DO:
    UNDO, THROW NEW Progress.Lang.AppError(SUBSTITUTE(
      "Failed socket connection (&1) to node server (&2).",
      cConnStr,
      ERROR-STATUS:GET-MESSAGE(1)
    ), 1).
  END.
  
  /* Socket options */
  lStatus = hNodeServer:SET-SOCKET-OPTION("TCP-NODELAY":U, "TRUE":U).
  IF lStatus = FALSE THEN DO:
    UNDO, THROW NEW Progress.Lang.AppError(SUBSTITUTE(
      "hNodeServer:SET-SOCKET-OPTION(~'TCP-NODELAY~', ~'TRUE~') = &1 (&2)":U,
      lStatus,
      ERROR-STATUS:GET-MESSAGE(1)
    ), 1).
  END.
  
  lStatus = hNodeServer:SET-READ-RESPONSE-PROCEDURE("Node-Response", THIS-PROCEDURE).
  IF lStatus = FALSE THEN DO:
    UNDO, THROW NEW Progress.Lang.AppError(SUBSTITUTE(
      "hNodeServer:SET-READ-RESPONSE-PROCEDURE('Node-Response', THIS-PROCEDURE) = &1 (&2)":U,
      lStatus,
      ERROR-STATUS:GET-MESSAGE(1)
    ), 1).
  END.
  
  lStatus = hNodeServer:SET-SOCKET-OPTION("SO-RCVBUF", STRING(16384)).
  lStatus = hNodeServer:SET-SOCKET-OPTION("SO-SNDBUF", STRING(iLength)).
  
  RETURN TRUE.
END FUNCTION.


/* send given memptr to server handle */
FUNCTION sendData LOGICAL(mOut AS MEMPTR):
  DEFINE VARIABLE lStatus AS LOGICAL   NO-UNDO.
  DEFINE VARIABLE iLength AS INTEGER NO-UNDO.
  
  iLength = GET-SIZE(mOut) - 1.
  
  msg("dbg", SUBSTITUTE("Node request: &1B", iLength)).
  lStatus = hNodeServer:WRITE(mOut, 1, iLength) NO-ERROR.
  IF lStatus = FALSE THEN DO:
    UNDO, THROW NEW Progress.Lang.AppError(SUBSTITUTE("hNodeServer:WRITE(mOut, 1, iLength=&1) (&2)":U, iLength, ERROR-STATUS:GET-MESSAGE(1)), 1).
  END.
  
  IF hNodeServer:BYTES-WRITTEN <> iLength THEN DO: 
    UNDO, THROW NEW Progress.Lang.AppError(SUBSTITUTE("hNodeServer:BYTES-WRITTEN (&1) <> iLength (&2)":U, hNodeServer:BYTES-WRITTEN, iLength), 1).
  END. 
END FUNCTION.


/* read data from node (awaits response if needed) */
FUNCTION readData LONGCHAR():
  DEFINE VARIABLE cNodeReq AS CHARACTER.
  DEFINE VARIABLE lcOutput AS LONGCHAR.
  
  oMemPtr = NEW MemoryPointer(16384).
  
  lResponseEnd = FALSE.
  
  REPEAT WHILE hNodeServer:CONNECTED() OR NOT lResponseEnd:
    IF lResponseEnd = TRUE THEN 
      LEAVE.
    WAIT-FOR "READ-RESPONSE":U OF hNodeServer PAUSE 10.
  END.
  
  IF VALID-HANDLE(hNodeServer) THEN DO:
    IF hNodeServer:CONNECTED() THEN hNodeServer:DISCONNECT() NO-ERROR.
    DELETE OBJECT hNodeServer NO-ERROR.
  END.

  lcOutput = oMemPtr:getLongCharSlice(1, -5).
  
  RETURN lcOutput.
END FUNCTION.

/* ***************************  Main Block  *************************** */

mData = prepareData (oJsonObject).

prepareConnection(GET-SIZE(mData) - 1).

sendData(mData).

lcOut = readData().

FINALLY:
  IF VALID-HANDLE(hNodeServer) THEN DO:
    IF hNodeServer:CONNECTED() THEN hNodeServer:DISCONNECT() NO-ERROR.
    DELETE OBJECT hNodeServer NO-ERROR.
  END.
  msg("dbg", "End.":U).
  RETURN.
END FINALLY.


/* ***************************  Procedures  *************************** */

PROCEDURE Node-Response:
  DEFINE VARIABLE lastBytes AS CHARACTER NO-UNDO.
  
  IF NOT hNodeServer:CONNECTED() THEN 
  DO:
    msg("wrn", "Not connected hNodeServer in Node-Response").
    RETURN.
  END.
  
  lStatus = hNodeServer:READ(mNodeResp, 1, 16384, 1) NO-ERROR.
  IF lStatus = FALSE THEN  DO:
    UNDO, THROW NEW GeneralError(SUBSTITUTE(
      "Read from hNodeServer socket error (1). hNodeServer:CONNECTED() = &1. lStatus = &2. hNodeServer:GET-BYTES-AVAILABLE() = &3. hNodeServer:BYTES-READ = &4. GET-SIZE(mNodeResp) = &5. ERROR-STATUS:ERROR = &6. ERROR-STATUS:GET-MESSAGE(1) = &7.",
      hNodeServer:CONNECTED(),
      lStatus,
      hNodeServer:GET-BYTES-AVAILABLE(),
      hNodeServer:BYTES-READ,
      GET-SIZE(mNodeResp),
      ERROR-STATUS:ERROR,
      ERROR-STATUS:GET-MESSAGE(1)
    )).
  END.
  
  iReadLength = hNodeServer:BYTES-READ.
  
  IF iReadLength > 0 THEN DO:
    oMemPtr:appendData(mNodeResp, iReadLength).
    iLength = iLength + iReadLength.

    /* part of end sign was read before, go back and delete it*/
    IF iReadLength < 5 THEN DO:
      msg("dbg", SUBSTITUTE("Less than 5 bytes from last chunk. Node response end (&1B)", iLength)) .
      lResponseEnd = TRUE.
      RETURN.
    END.

    DO ON ERROR UNDO, THROW :
      lastBytes = oMemPtr:getLongCharSlice(-5).
      IF lastBytes = "~{~{E~}~}" THEN DO:
        msg("dbg", SUBSTITUTE("Read data end sign from Node (&1B)", iLength)) .
        lResponseEnd = TRUE.
      END.
      
      CATCH err AS Progress.Lang.Error :
        /* Err 12012: Invalid character data found.
           we expect this when last 5 bytes split utf symbol in half
        */
        IF err:GetMessageNum(1) <> 12012 THEN DO:
          UNDO, THROW err.
        END.
      END CATCH.
    END.
  END.
  ELSE IF hNodeServer:CONNECTED() THEN DO:
    UNDO, THROW NEW Progress.Lang.AppError(SUBSTITUTE(
      "Read from hNodeServer socket error (2). hNodeServer:CONNECTED() = &1. iReadLength = &2. lStatus = &3. hNodeServer:GET-BYTES-AVAILABLE() = &4. hNodeServer:BYTES-READ = &5. GET-SIZE(mNodeResp) = &6":U, hNodeServer:CONNECTED(),
      iReadLength, 
      lStatus, 
      hNodeServer:GET-BYTES-AVAILABLE(), 
      hNodeServer:BYTES-READ, 
      GET-SIZE(mNodeResp)
    )).
  END.
  
END PROCEDURE.
