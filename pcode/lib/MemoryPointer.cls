
 /*------------------------------------------------------------------------
    File        : MemoryPointer
    Purpose     : Wrapper for MEMPTR with append functionality
                      and different getters

    Author(s)   : Hustlethroat
    Created     : Tue Mar 17 18:00:45 EET 2015
  ----------------------------------------------------------------------*/

BLOCK-LEVEL ON ERROR UNDO, THROW.

USING Progress.Lang.*.


CLASS mainib.web.core.lib.MemoryPointer:

    DEFINE PRIVATE PROPERTY mPointer  AS MEMPTR NO-UNDO GET. SET.
    DEFINE PRIVATE PROPERTY iDataSize AS INT64  NO-UNDO GET. SET.

    CONSTRUCTOR PUBLIC MemoryPointer ( iInitSize AS INT64 ):
        SET-SIZE (mPointer) = 0.
        SET-SIZE (mPointer) = iInitSize.
        iDataSize = 0.
    END CONSTRUCTOR.


    DESTRUCTOR PUBLIC MemoryPointer ( ):
        SET-SIZE (mPointer) = 0.
    END DESTRUCTOR.


    METHOD PUBLIC VOID appendData ( mSource AS MEMPTR ):

        appendData(mSource, GET-SIZE (mSource)).

    END METHOD.


    METHOD PUBLIC VOID appendData ( mSource AS MEMPTR, iSourceSize AS INT64 ):

        DEFINE VARIABLE iRequiredSize AS INT64 NO-UNDO.
        DEFINE VARIABLE iCurrentSize  AS INT64 NO-UNDO.

        DEFINE VARIABLE cc AS CHARACTER NO-UNDO.

        iRequiredSize = iDataSize + iSourceSize.
        iCurrentSize  = GET-SIZE (mPointer).

        IF iRequiredSize > iCurrentSize THEN DO:
            THIS-OBJECT:extendSize(iRequiredSize * 2).
        END.

        COPY-LOB
          FROM mSource  FOR iSourceSize
            TO mPointer OVERLAY AT iDataSize + 1
          NO-CONVERT.

        iDataSize = iRequiredSize.

    END METHOD.


    METHOD PUBLIC LONGCHAR getLongChar ():

        RETURN getLongCharSlice(1).

    END METHOD.


    METHOD PUBLIC LONGCHAR getLongCharSlice ( iStart AS INT64 ):

        RETURN getLongCharSlice(iStart, iDataSize + 1).

    END METHOD.


    /* memptr byte slice, from iStart (inclusive) to iEnd (exclusive) */
    METHOD PUBLIC LONGCHAR getLongCharSlice ( iStart AS INT64, iEnd AS INT64 ):

        DEFINE VARIABLE mTrimmed AS MEMPTR   NO-UNDO.
        DEFINE VARIABLE lcOutput AS LONGCHAR NO-UNDO.

        /* we can't just use [COPY-LOB ... FROM ... FOR ...] 
            because 'FOR' expects char count when target is longchar.
            We don't know the amount of full chars we have,
            therefore we slice memptr and copy it to longhchar fully
        */
        mTrimmed = THIS-OBJECT:getMemptrSlice (iStart, iEnd).
        COPY-LOB FROM mTrimmed TO lcOutput NO-CONVERT.

        RETURN lcOutput.

        FINALLY:
            SET-SIZE (mTrimmed) = 0.
        END FINALLY.

    END METHOD.


    /* memptr byte slice, from iStart (inclusive) to iEnd (exclusive) 
        accepts negative parameters, interpretting them as index from the end
    */
    METHOD PUBLIC MEMPTR getMemptrSlice ( iStart AS INT64, iEnd AS INT64 ):
        
        DEFINE VARIABLE mOutput   AS MEMPTR NO-UNDO.
        DEFINE VARIABLE iCopySize AS INT64 NO-UNDO.

        IF iStart < 0 THEN DO:
            iStart = iDataSize + iStart + 1.
        END.
        IF iEnd < 0 THEN DO:
            iEnd = iDataSize + iEnd + 1.
        END.

        iCopySize = iEnd - iStart.

        SET-SIZE (mOutput) = 0.
        SET-SIZE (mOutput) = iCopySize.

        COPY-LOB 
          FROM mPointer STARTING AT iStart FOR iCopySize 
          TO mOutput NO-CONVERT.

        RETURN mOutput.
        
    END METHOD.


    /* extend size of memptr to provided target */
    METHOD PRIVATE VOID extendSize ( iTargetSize AS INT64 ):

        DEFINE VARIABLE mBuffer AS MEMPTR NO-UNDO.

        SET-SIZE (mBuffer) =  GET-SIZE (mPointer).
        COPY-LOB FROM mPointer TO mBuffer OVERLAY AT 1 NO-CONVERT.

        SET-SIZE (mPointer) = 0.
        SET-SIZE (mPointer) = iTargetSize.

        COPY-LOB FROM mBuffer TO mPointer OVERLAY AT 1 NO-CONVERT.

        FINALLY:
            SET-SIZE (mBuffer) = 0.
        END FINALLY.

    END METHOD.

END CLASS.
