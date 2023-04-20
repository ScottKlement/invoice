     H OPTION(*SRCSTMT:*NODEBUGIO)

     FITEMMAS   IF   E           K DISK    PREFIX(IM)
     FUNITS     IF   E           K DISK
     FITMINQD   CF   E             WORKSTN SFILE(ITMINQ1S:RRN1)

     D UPPER           c                   'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
     D LOWER           c                   'abcdefghijklmnopqrstuvwxyz'

     D RRN1            s              4p 0
     D HIGHRRN1        s                   like(RRN1)
     D ITEMNO          S                   like(IMITEMNO)
     D CANCEL          s              1n
     D UCDESCR         s                   like(IMDESCR)
     D UCFILTER        s             35a   varying
     D SAVEITEMNO      s                   like(IMITEMNO)
     D SAVEFILTER      s                   like(FILTER)
     D NUMSEL          s              5p 0

     C     *ENTRY        PLIST
     C                   PARM                    ITEMNO
     C                   PARM                    CANCEL

     C                   IF        %PARMS >= 2
     C                   EVAL      *IN40 = *OFF
     C                   EVAL      ITEMNO = 0
     C                   EVAL      CANCEL = *OFF
     C                   ELSE
     C                   EVAL      *IN40 = *ON
     C                   ENDIF

     C                   EVAL      FILTER = *BLANKS

     C                   DOU       *INLR = *ON
     C                   EXSR      LOADITEMS
     C                   EXSR      SHOWITEMS
     C                   ENDDO

     C                   IF        *IN40 = *OFF
     C                   EVAL      ITEMNO = SAVEITEMNO
     C                   EVAL      CANCEL = *IN03 or *IN12
     C                   ENDIF

     C                   RETURN


     C*===============================================================
     C* Load Items to be displayed onto screen
     C*===============================================================
     C     LOADITEMS     BEGSR
     C*-------------------------
     C                   EVAL      *IN50 = *ON
     C                   EVAL      *IN51 = *OFF
     C                   WRITE     ITMINQ1C
     C                   EVAL      *IN50 = *OFF
     C                   EVAL      HIGHRRN1 = 0
     C                   EVAL      LASTRRN1 = 0
     C                   EVAL      RRN1 = 0

     C                   IF        FILTER <> *BLANKS
     C                   eval      UCFILTER = %trim(FILTER)
     C                   eval      UCFILTER = %xlate(lower:upper:UCFILTER)
     C                   ENDIF

     C     *START        SETLL     ITEMMAS
     C                   READ      ITEMMAS                                10

     C                   DOW       *IN10 = *OFF

     C     IMUOM         CHAIN     UNITS                              10
     C                   IF        *IN10 = *ON
     C                   EVAL      UNDESC = *BLANKS
     C                   ENDIF

     C                   IF        FILTER = *BLANKS
     C                   EVAL      RRN1 = RRN1 + 1
     C                   WRITE     ITMINQ1S
     C                   ELSE
     C                   EVAL      UCDESCR = %XLATE(Lower:Upper:IMDESCR)
     C                   IF        %scan(UCFILTER:UCDESCR) > 0
     C                   EVAL      RRN1 = RRN1 + 1
     C                   WRITE     ITMINQ1S
     C                   ENDIF
     C                   ENDIF

     C                   READ      ITEMMAS                                10
     C                   ENDDO

     C                   EVAL      HIGHRRN1 = RRN1
     C                   IF        HIGHRRN1 > 0
     C                   EVAL      *IN51 = *ON
     C                   ENDIF
     C*-------------------------
     C                   ENDSR

     C*===============================================================
     C* Show loaded items to user
     C*===============================================================
     C     SHOWITEMS     BEGSR
     C*-------------------------
     C                   EVAL      SAVEFILTER = FILTER

     C                   DOU       MSG = *BLANKS AND *IN40 = *OFF

     C                   IF        LASTRRN1>=1 and LASTRRN1<=HIGHRRN1
     C                   EVAL      NEXTRRN1 = LASTRRN1
     C                   ELSE
     C                   EVAL      NEXTRRN1 = 1
     C                   ENDIF

     C                   WRITE     ITMINQ1F
     C                   EXFMT     ITMINQ1C
     C                   EVAL      MSG = *BLANKS
     C                   EVAL      SAVEITEMNO = 0
     C                   EVAL      NUMSEL = 0

     C                   IF        *IN03 or *IN12
     C                   EVAL      *INLR = *ON
     C                   LEAVESR
     C                   ENDIF

     C                   IF        FILTER <> SAVEFILTER
     C                   EVAL      *IN05 = *ON
     C                   EVAL      *INLR = *OFF
     C                   LEAVESR
     C                   ENDIF

     C                   IF        *IN05
     C                   LEAVESR
     C                   ENDIF

     C     1             DO        HIGHRRN1      RRN1

     C     RRN1          CHAIN     ITMINQ1S                           10
     C                   IF        *IN10 = *ON
     C                   ITER
     C                   ENDIF

     C                   IF        OPT = '1'
     C                   EVAL      SAVEITEMNO = IMITEMNO
     C                   EVAL      NUMSEL = NUMSEL + 1
     C                   ENDIF

     C                   IF        OPT<>'1' and OPT<>*BLANKS
     C                   EVAL      MSG = 'Options are 1=Select or blank'
     C                   ENDIF

     C                   ENDDO

     C                   IF        *IN40=*OFF

     C                   SELECT
     C                   WHEN      NUMSEL = 0
     C                   EVAL      MSG = 'You must select at least one +
     C                                   item!'
     C                   WHEN      NUMSEL > 1
     C                   EVAL      MSG = 'You may only select one item at a +
     C                                    time!'
     C                   OTHER
     C                   EVAL      *INLR = *ON
     C                   ENDSL

     C                   ENDIF

     C                   ENDDO
     C*-------------------------
     C                   ENDSR
