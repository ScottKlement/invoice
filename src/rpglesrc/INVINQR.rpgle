     H OPTION(*SRCSTMT:*NODEBUGIO)

      /undefine MACOS
.....F*ilename++IPEASFRlen+LKlen+AIDevice+.Keywords+++++++++++++++++++++++++     FUNITS     IF   E
     FINVHDR    IF   E           K DISK
     FINVDET    IF   E           K DISK
     FITEMMAS   IF   E           K DISK    PREFIX(IM)
     FINVINQD   CF   E             WORKSTN SFILE(INVINQ2S:RRN2)
     F                                     SFILE(INVINQ3S:RRN3)

.....D*ame+++++++++++ETDsFrom+++To/L+++IDc.Keywords+++++++++++++++++++++++++
     D DATEFLD         S               D   DATFMT(*ISO)
     D URL             s            300a   varying
     D CMD             s           2000a   varying

     D QCMDEXC         PR                  extpgm('QCMDEXC')
     D   cmd                       2000a   const
     D   len                         15p 5 const

.....C*0N01Factor1+++++++Opcode&ExtFactor2+++++++Result++++++++Len++D+HiLoEq
     C     *INLR         DOUEQ     *ON

     C                   SELECT
     C     STEP          WHENEQ    1
     C                   EXSR      ASKINVNO
     C     STEP          WHENEQ    2
     C                   EXSR      LOADINV
     C     STEP          WHENEQ    3
     C     MODE          IFNE      'B'
     C                   EXSR      SHOWSHIP
     C                   ELSE
     C                   EXSR      SHOWBILL
     C                   ENDIF
     C                   OTHER
     C                   Z-ADD     0             STEP              5 0
     C                   MOVE      *OFF          *IN03
     C                   MOVE      *OFF          *IN12
     C                   ENDSL

     C                   IF        *IN03 or *IN12
     C                   SUB       1             STEP
     C                   ELSE
     C                   ADD       1             STEP
     C                   ENDIF

     C                   ENDDO

     C                   MOVE      *ON           *INLR
     C                   RETURN



     C*=============================================================
     C* Ask the user for the invoice number to view
     C*=============================================================
     C     ASKINVNO      BEGSR
     C*------------------------
     C                   MOVE      *OFF          *IN03
     C                   MOVE      *OFF          *IN12

     C     SCMSG         DOUEQ     *BLANKS

     C                   EXFMT     INVINQ1
     C                   MOVEL     *BLANKS       SCMSG

     C     *IN03         IFEQ      *ON
     C     *IN12         OREQ      *ON
     C                   MOVE      *ON           *INLR
     C                   LEAVESR
     C                   ENDIF

     C     SCINVNO       IFLE      0
     C                   EVAL      SCMSG = 'Please enter an invoice number!'
     C                   ITER
     C                   ENDIF

     C     SCINVNO       CHAIN     INVHDR                             10
     C     *IN10         IFEQ      *ON
     C                   EVAL      SCMSG = 'Invoice not found!'
     C                   ITER
     C                   ENDIF

     C                   ENDDO
     C*------------------------
     C                   ENDSR


     C*=============================================================
     C* Load invoice into memory
     C*=============================================================
     C     LOADINV       BEGSR
     C*------------------------
     C     *IN03         IFEQ      *ON
     C     *IN12         OREQ      *ON
     C                   LEAVESR
     C                   ENDIF

     C                   MOVE      *ON           *IN50
     C                   MOVE      *OFF          *IN51
     C                   WRITE     INVINQ2C
     C                   WRITE     INVINQ3C
     C                   MOVE      *OFF          *IN50
     C                   Z-ADD     0             RRN2              4 0
     C                   Z-ADD     0             RRN3              4 0
     C                   Z-ADD     0             HIGHRRN           4 0

     C                   MOVE      INVNO         SCINVNO
     C                   MOVEL     CUSTPO        SCCUSTPO
     C                   MOVE      CUSTNO        SCCUSTNO

     C                   MOVEL     DELNAME       SCDELNAME
     C                   MOVEL     DELCONT       SCDELCONT
     C                   MOVEL     DELSTREET     SCDELSTR
     C                   MOVEL     DELCITY       SCDELCITY
     C                   MOVEL     DELSTATE      SCDELSTATE
     C                   MOVEL     DELPOSTAL     SCDELPOST
     C                   MOVEL     DELCNTRY      SCDELCNTRY
     C                   MOVEL     BILNAME       SCBILNAME
     C                   MOVEL     BILCONT       SCBILCONT
     C                   MOVEL     BILSTREET     SCBILSTR
     C                   MOVEL     BILCITY       SCBILCITY
     C                   MOVEL     BILSTATE      SCBILSTATE
     C                   MOVEL     BILPOSTAL     SCBILPOST
     C                   MOVEL     BILCNTRY      SCBILCNTRY
     C                   MOVEL     MSG1          SCMSG1
     C                   MOVEL     MSG2          SCMSG2
     C                   MOVEL     MSG3          SCMSG3

     C     CRTDATE       IFEQ      0
     C                   MOVEL     *BLANKS       SCCRTDATE
     C                   ELSE
     C     *ISO          MOVE      CRTDATE       DATEFLD
     C     *USA          MOVE      DATEFLD       SCCRTDATE
     C                   ENDIF

     C     DELDATE       IFEQ      0
     C                   MOVEL     *BLANKS       SCDELDATE
     C                   ELSE
     C     *ISO          MOVE      DELDATE       DATEFLD
     C     *USA          MOVE      DATEFLD       SCDELDATE
     C                   ENDIF

     C     INVDATE       IFEQ      0
     C                   MOVEL     *BLANKS       SCINVDATE
     C                   ELSE
     C     *ISO          MOVE      INVDATE       DATEFLD
     C     *USA          MOVE      DATEFLD       SCINVDATE
     C                   ENDIF

     C     PAIDDATE      IFEQ      0
     C                   MOVEL     *BLANKS       SCPAYDATE
     C                   ELSE
     C     *ISO          MOVE      PAIDDATE      DATEFLD
     C     *USA          MOVE      DATEFLD       SCPAYDATE
     C                   ENDIF

     C     PODATE        IFEQ      0
     C                   MOVEL     *BLANKS       SCPODATE
     C                   ELSE
     C     *ISO          MOVE      PODATE        DATEFLD
     C     *USA          MOVE      DATEFLD       SCPODATE
     C                   ENDIF

     C                   Z-ADD     0             SCSUBTOT
     C                   Z-ADD     0             SCTOTWGT
     C                   Z-ADD     SHIPPING      SCSHIP
     C                   Z-ADD     TAX           SCTAX

     C     INVNO         SETLL     INVDET
     C     INVNO         READE     INVDET                                 10
     C     *IN10         DOWEQ     *OFF

.....C*0N01Factor1+++++++Opcode&ExtFactor2+++++++Result++++++++Len++D+HiLoEq
     C     ITEMNO        CHAIN     ITEMMAS                            10
     C     IMPRODUCT     IFNE      'Y'
     C                   MOVEL     'N'           IMPRODUCT
     C                   ENDIF
     C   10              MOVEL     *BLANKS       IMPRODUCT

     C                   MOVE      ITEMNO        SCITEMNO
     C                   MOVE      IMPRODUCT     SCPRODUCT
     C                   Z-ADD     QTY           SCQTY
     C                   MOVE      UOM           SCUOM
     C                   MOVEL     DESCR         SCDESCR
     C                   Z-ADD     PRICE         SCPRICE
     C                   Z-ADD     WGTLBS        SCWGTLBS
     C     PRICE         MULT(H)   QTY           SCEXTN

     C                   ADD       SCEXTN        SCSUBTOT
     C                   ADD       SCWGTLBS      SCTOTWGT

     C                   ADD       1             RRN2
     C                   ADD       1             RRN3
     C                   MOVE      *ON           *IN51
     C                   WRITE     INVINQ2S
     C                   WRITE     INVINQ3S

     C     INVNO         READE     INVDET                                 10
     C                   ENDDO

     C     SCSUBTOT      ADD       SCSHIP        SCTOTAL
     C                   ADD       SCTAX         SCTOTAL
     C                   MOVEL     'S'           MODE              1
     C*------------------------
     C                   ENDSR


     C*=============================================================
     C* Show the delivery (shipping) data screen
     C*=============================================================
     C     SHOWSHIP      BEGSR
     C*------------------------
     C     *INLR         DOUEQ     *ON

     C                   WRITE     INVINQ2F
     C                   EXFMT     INVINQ2C
     C                   MOVEL     *BLANKS       SCMSG

     C     *IN03         IFEQ      *ON
     C     *IN12         OREQ      *ON
     C                   LEAVESR
     C                   ENDIF

     C     *IN25         IFEQ      *ON
     C                   MOVE      *OFF          *IN25
     C                   EXSR      OPENURL
     C                   ENDIF

     C     *IN08         IFEQ      *ON
     C                   MOVEL     'B'           MODE
     C                   Z-ADD     2             STEP
     C                   LEAVESR
     C                   ENDIF

     C                   ENDDO
     C*------------------------
     C                   ENDSR


     C*=============================================================
     C* Show the bill-to (billing) data screen
     C*=============================================================
     C     SHOWBILL      BEGSR
     C*------------------------
     C     *INLR         DOUEQ     *ON

     C                   WRITE     INVINQ3F
     C                   EXFMT     INVINQ3C
     C                   MOVEL     *BLANKS       SCMSG

     C     *IN03         IFEQ      *ON
     C     *IN12         OREQ      *ON
     C                   LEAVESR
     C                   ENDIF

     C     *IN25         IFEQ      *ON
     C                   MOVE      *OFF          *IN25
     C                   EXSR      OPENURL
     C                   ENDIF

     C     *IN08         IFEQ      *ON
     C                   MOVEL     'S'           MODE
     C                   Z-ADD     2             STEP
     C                   LEAVESR
     C                   ENDIF

     C                   ENDDO
     C*------------------------
     C                   ENDSR


     C*=============================================================
     C* Open a URL to a GUI print of the invoice
     C*=============================================================
     C     OPENURL       BEGSR
     C*------------------------
     C                   EVAL      url = 'http://i.scottklement.com'
     C                                 + '/invoices'
     C                                 + '/inv' + %editc(invno:'X') + '.pdf'

     C                   EVAL      cmd = 'STRPCO'
     C                   CALLP(E)  QCMDEXC(cmd:%len(cmd))

     C                   EVAL      cmd = 'STRPCCMD PCCMD('''
     C                                 + 'open '
     C                                 + url
     C                                 + ''') PAUSE(*NO)'
     C                   CALLP     QCMDEXC(cmd:%len(cmd))
     C*------------------------
     C                   ENDSR
