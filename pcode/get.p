BLOCK-LEVEL ON ERROR UNDO, THROW.

USING Progress.Json.ObjectModel.JsonObject.
USING Progress.Json.ObjectModel.JsonArray.

{src/web2/wrap-cgi.i}

FUNCTION msg LOGICAL (cLevel AS CHARACTER, cMsg AS CHARACTER):
  IF LOG-MANAGER:LOGFILE-NAME <> ? THEN DO:
    LOG-MANAGER:WRITE-MESSAGE (cMsg, CAPS (cLevel)).
  END.
  ELSE DO:
    MESSAGE SUBSTITUTE(":&1: &2", STRING(cLevel, "x(7)"), cMsg).
  END.
END FUNCTION.

FUNCTION get_articles JsonArray (jsIds AS JsonArray):
  DEFINE VARIABLE jsArticles AS JsonArray NO-UNDO.
  DEFINE VARIABLE jsArticle AS JsonObject NO-UNDO.
  jsArticles = NEW JsonArray().

  DO WHILE jsIds:Length > 0:
    FIND wiki_articles NO-LOCK
      WHERE wiki_articles.id = jsIds:GetInt64(1) NO-ERROR.
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

DEFINE VARIABLE cQuery AS CHARACTER  NO-UNDO.
DEFINE VARIABLE jsOut  AS JsonObject NO-UNDO.
DEFINE VARIABLE lcOut  AS LONGCHAR   NO-UNDO.

msg("inf", 'Start get.p').

cQuery = get-value("q").

msg("dbg", SUBSTITUTE("Query value: &1", cQuery)).

jsOut = NEW JsonObject().
jsOut:Add("q", cQuery).
/* begin temporary */
DEFINE VARIABLE jsIds AS JsonArray NO-UNDO.
jsIds = NEW JsonArray().
jsIds:Add(23725001).
jsIds:Add(23725004).
/* end temporary */
jsOut:Add("articles", get_articles(jsIds)).
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

