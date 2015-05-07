BLOCK-LEVEL ON ERROR UNDO, THROW.

USING Progress.Json.ObjectModel.JsonObject.

{src/web2/wrap-cgi.i}

FUNCTION msg RETURNS LOGICAL (cLevel AS CHARACTER, cMsg AS CHARACTER):
  IF LOG-MANAGER:LOGFILE-NAME <> ? THEN DO:
    LOG-MANAGER:WRITE-MESSAGE (cMsg, CAPS (cLevel)).
  END.
  ELSE DO:
    MESSAGE SUBSTITUTE(":&1: &2", STRING(cLevel, "x(7)"), cMsg).
  END.
END FUNCTION.

DEFINE VARIABLE cQuery     AS CHARACTER  NO-UNDO.
DEFINE VARIABLE jsOut      AS JsonObject NO-UNDO.
DEFINE VARIABLE lcOut      AS LONGCHAR   NO-UNDO.
DEFINE VARIABLE lcNodeResp AS LONGCHAR   NO-UNDO.
DEFINE VARIABLE jsNodeResp AS JsonObject NO-UNDO.

DEFINE VARIABLE jsParser   AS ObjectModelParser NO-UNDO.

msg("inf", 'Start get.p').

cQuery = get-value("q").

msg("dbg", SUBSTITUTE("Query value: &1", cQuery)).

RUN lib/nodeTransport.p (INPUT cQuery, OUTPUT lcNodeResp).

jsParser = NEW ObjectModelParser().
jsNodeResp = CAST(jsParser:Parse (lcNodeResp), JsonObject) NO-ERROR.
IF ERROR-STATUS:ERROR THEN DO:
    msg("wrn", SUBSTITUTE (
        "Could not parse node response as JsonObject. Response: &1",
        SUBSTRING (lcNodeResp, 1, MIN (LENGTH (lcNodeResp), 1000))
    )).
    jsNodeResp = NEW JsonObject().
END.

jsOut = NEW JsonObject().
jsOut:Add("q", cQuery).
jsOut:Write(lcOut).

msg("dbg", "Before output").

/* headers */
PUT STREAM-HANDLE {&WEBSTREAM}:HANDLE CONTROL
  "Content-Type: "
  "application/json;charset=utf-8"
  "~r~n"
  "~r~n".

/* data */
PUT STREAM-HANDLE {&WEBSTREAM}:HANDLE UNFORMATTED STRING(lcOut).

CATCH oErr AS Progress.Lang.AppError:
  msg("err", oErr:GetMessage(1)).
END CATCH.

FINALLY :
  msg("inf", 'End get.p').
END FINALLY.
