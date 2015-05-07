BLOCK-LEVEL ON ERROR UNDO, THROW.

USING Progress.Json.ObjectModel.JsonObject.
USING Progress.Json.ObjectModel.JsonArray.
USING Progress.Json.ObjectModel.ObjectModelParser.

{src/web2/wrap-cgi.i}

FUNCTION msg RETURNS LOGICAL (cLevel AS CHARACTER, cMsg AS CHARACTER):
  IF LOG-MANAGER:LOGFILE-NAME <> ? THEN DO:
    LOG-MANAGER:WRITE-MESSAGE (cMsg, CAPS (cLevel)).
  END.
  ELSE DO:
    MESSAGE SUBSTITUTE(":&1: &2", STRING(cLevel, "x(7)"), cMsg).
  END.
END FUNCTION.

FUNCTION getArticles JsonArray (jsIds AS JsonArray):
  DEFINE VARIABLE jsArticles AS JsonArray NO-UNDO.
  DEFINE VARIABLE jsArticle AS JsonObject NO-UNDO.
  jsArticles = NEW JsonArray().

  DO WHILE jsIds:Length > 0:
    FIND wiki_articles NO-LOCK
      WHERE wiki_articles.id = jsIds:GetJsonObject(1):GetInt64('id') NO-ERROR.
    IF AVAILABLE wiki_articles THEN DO:
      jsArticle = NEW JsonObject().
      jsArticle:Add("id", wiki_articles.id).
      jsArticle:Add("title", wiki_articles.wiki_title).
      jsArticle:Add("article", wiki_articles.wiki_article).
      jsArticles:Add(jsArticle).
    END.
    jsIds:Remove(1).
  END.

  RETURN jsArticles.
END FUNCTION.

FUNCTION outputContent LOGICAL (lcContent AS LONGCHAR):
  DEFINE VARIABLE iTotal   AS INTEGER NO-UNDO.
  DEFINE VARIABLE iOutput  AS INTEGER NO-UNDO INIT 0.
 
  iTotal = LENGTH (lcContent).
 
  /* max string - 32000kB, using smaller chunks in case we get double-byte symbols */
  REPEAT WHILE iOutput + 10000 < iTotal :
    PUT STREAM-HANDLE {&WEBSTREAM}:HANDLE UNFORMATTED STRING(SUBSTRING (lcContent, iOutput + 1, 10000)).
    iOutput = iOutput + 10000.
  END.
  PUT STREAM-HANDLE {&WEBSTREAM}:HANDLE UNFORMATTED STRING(SUBSTRING(lcContent, iOutput + 1)).
END METHOD.


DEFINE VARIABLE cQuery     AS CHARACTER  NO-UNDO.
DEFINE VARIABLE jsNodeReq  AS JsonObject NO-UNDO.
DEFINE VARIABLE jsOut      AS JsonObject NO-UNDO.
DEFINE VARIABLE lcOut      AS LONGCHAR   NO-UNDO.
DEFINE VARIABLE lcNodeResp AS LONGCHAR   NO-UNDO.
DEFINE VARIABLE jsNodeResp AS JsonObject NO-UNDO.
DEFINE VARIABLE jsIds      AS JsonArray  NO-UNDO.
DEFINE VARIABLE jsParser   AS ObjectModelParser NO-UNDO.

msg("inf", 'Start get.p').

cQuery = get-value("q").

msg("dbg", SUBSTITUTE("Query value: &1", cQuery)).

jsNodeReq = NEW JsonObject().
jsNodeReq:Add("q", cQuery).
RUN lib/nodeTransport.p (INPUT jsNodeReq, OUTPUT lcNodeResp).
msg("dbg", STRING(lcNodeResp)).
jsParser = NEW ObjectModelParser().
jsNodeResp = CAST(jsParser:Parse (lcNodeResp), JsonObject) NO-ERROR.
IF ERROR-STATUS:ERROR THEN DO:
    msg("wrn", SUBSTITUTE (
        "Could not parse node response as JsonObject, &1. Response: &2",
        ERROR-STATUS:GET-MESSAGE(1),
        SUBSTRING (lcNodeResp, 1, MIN (LENGTH (lcNodeResp), 1000))
    )).
    jsNodeResp = NEW JsonObject().
END.
jsOut = NEW JsonObject().
jsOut:Add("q", cQuery).

jsIds = jsNodeResp:GetJsonArray("rows").
jsOut:Add("articles", getArticles(jsIds)).
jsOut:Write(lcOut).

msg("dbg", "Before output").

/* headers */
PUT STREAM-HANDLE {&WEBSTREAM}:HANDLE CONTROL
  "Content-Type: "
  "application/json;charset=utf-8"
  "~r~n"
  "~r~n".

/* data */
outputContent(lcOut).

CATCH oErr AS Progress.Lang.AppError:
  msg("err", oErr:GetMessage(1)).
END CATCH.

FINALLY :
  msg("inf", 'End get.p').
END FINALLY.

