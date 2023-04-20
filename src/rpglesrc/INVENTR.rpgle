     H OPTION(*SRCSTMT:*NODEBUGIO) 
      /if defined(*CRTBNDRPG)
     H DFTACTGRP(*NO) ACTGRP('MAIN')
      /endif

     FCUSTMAS   UF   E           K DISK    PREFIX(CM)
     FITEMMAS   IF   E           K DISK    PREFIX(IM)
     FUNITS     IF   E           K DISK
     FINVHDR    UF A E           K DISK
     FINVDET    UF A E           K DISK
     FCTRLDTA   UF A E           K DISK
     FINVENTD   CF   E             WORKSTN SFILE(INVENT1S:RRN1)
     F                                     SFILE(INVENT4S:RRN4)

     D TOJOB           PR             6S 0
     D   DTISO                        8S 0 value
     D TOISO           PR             8S 0
     D   DTJOB                        6S 0 value

     D RRN1            s              4p 0
     D RRN4            s              4p 0
     D STEP            S              3p 0 inz(1)
     D HIGHRRN1        s                   like(RRN1)
     D HIGHRRN4        s                   like(RRN4)
     D NUMSEL          S              4p 0
     D CHANGE          S              1a
     D EMPTY           s              4p 0
     D NEWORDER        S              1a
     D PITEMNO         s                   like(IMITEMNO)
     D CANCEL          s              1n   inz(*off)
     D MYLINENO        s                   like(LINENO)

     C                   DOU       *INLR = *ON

     C                   SELECT
     C                   WHEN      STEP = 1
     C                   EXSR      LOADORDLIST
     C                   WHEN      STEP = 2
     C                   EXSR      SELORD
     C                   WHEN      STEP = 3
     C                   EXSR      NEWORD
     C                   WHEN      STEP = 4
     C                   EXSR      LOADORD
     C                   WHEN      STEP = 5
     C                   EXSR      CUSTINFO
     C                   WHEN      STEP = 6
     C                   EXSR      ITEMS
     C                   WHEN      STEP = 7
     C                   EXSR      FOOTERMSG
     C                   WHEN      STEP = 8
     C                   EXSR      SAVEORD
     C                   OTHER
     C                   EVAL      *INLR = *ON
     C                   ENDSL

     C                   IF        *IN03=*ON or *IN12=*ON
     C                   EVAL      STEP = STEP - 1
     C                   ELSE
     C                   EVAL      STEP = STEP + 1
     C                   ENDIF

     C                   ENDDO

     C                   RETURN


     C*=============================================================
     C* Load the list of previous orders to select from
     C*=============================================================
     C     LOADORDLIST   BEGSR
     C*------------------------
     C                   EVAL      *IN03 = *OFF
     C                   EVAL      *IN12 = *OFF
     C                   EVAL      *IN51 = *OFF
     C                   EVAL      *IN50 = *ON
     C                   EVAL      RRN1 = 0
     C                   EVAL      HIGHRRN1 = 0
     C                   EVAL      LASTRRN1 = 0

     C                   WRITE     INVENT1C
     C                   EVAL      *IN50 = *OFF
     C                   EVAL      MSG = *BLANKS

     C     *START        SETLL     INVHDR
     C                   READ(N)   INVHDR                                 10
     C                   DOW       *IN10 = *OFF

     C                   IF        PAIDDATE = 0
     C                   EVAL      CRTDATE6 = TOJOB(CRTDATE)
     C                   EVAL      RRN1 = RRN1 + 1
     C                   EVAL      *IN51 = *ON
     C                   EVAL      OPT = *BLANKS
     C                   WRITE     INVENT1S
     C                   ENDIF

     C                   READ(N)   INVHDR                                 10
     C                   ENDDO

     C                   EVAL      HIGHRRN1 = RRN1
     C                   IF        HIGHRRN1 = 0
     C                   CLEAR                   INVENT1S
     C                   EVAL      RRN1 = RRN1 + 1
     C                   WRITE     INVENT1S
     C                   ENDIF
     C*------------------------
     C                   ENDSR


     C*=============================================================
     C*  Select an order to change
     C*=============================================================
     C     SELORD        BEGSR
     C*------------------------
     C                   DOU       MSG = *BLANKS

     C                   IF        LASTRRN1 > HIGHRRN1
     C                             OR LASTRRN1 < 1
     C                   EVAL      NEXTRRN1 = 1
     C                   ELSE
     C                   EVAL      NEXTRRN1 = LASTRRN1
     C                   ENDIF

     C                   WRITE     INVENT1F
     C                   EXFMT     INVENT1C
     C                   EVAL      MSG = *BLANKS
     C                   EVAL      NUMSEL = 0
     C                   EVAL      NEWORDER = 'N'

     C                   SELECT
     C                   WHEN      *IN03=*ON or *IN12=*ON
     C                   EVAL      *INLR = *ON
     C                   LEAVESR
     C                   WHEN      *IN05=*ON
     C                   EVAL      *IN12 = *ON
     C                   LEAVESR
     C                   WHEN      *IN06=*ON
     C                   LEAVESR
     C                   ENDSL

     C     1             DO        HIGHRRN1      RRN1

     C     RRN1          CHAIN     INVENT1S                           10
     C                   IF        *IN10 = *OFF

     C                   SELECT
     C                   WHEN      OPT = '2'
     C                   EVAL      NUMSEL = NUMSEL + 1
     C                   EVAL      STEP = STEP + 1
     C                   EVAL      SAVEINVNO  = INVNO
     C                   EVAL      SAVECUST   = CUSTNO
     C                   EVAL      SAVECRTDT6 = CRTDATE6
     C                   EVAL      SAVEAMT    = TOTAL
     C                   WHEN      OPT = '4'
     C                   EVAL      NUMSEL = NUMSEL + 1
     C                   EVAL      SAVEINVNO  = INVNO
     C                   EVAL      SAVECUST   = CUSTNO
     C                   EVAL      SAVECRTDT6 = CRTDATE6
     C                   EVAL      SAVEAMT    = TOTAL
     C                   EXSR      DELETEINV
     C                   WHEN      OPT = '9'
     C                   EVAL      NUMSEL = NUMSEL + 1
     C                   EVAL      SAVEINVNO  = INVNO
     C                   EVAL      SAVECUST   = CUSTNO
     C                   EVAL      SAVECRTDT6 = CRTDATE6
     C                   EVAL      SAVEAMT    = TOTAL
     C                   EXSR      PAYINV
     C                   ENDSL

     C                   EVAL      OPT = ' '
     C                   UPDATE    INVENT1S
     C                   ENDIF

     C                   ENDDO

     C                   IF        NUMSEL = 0
     C                   EVAL      MSG = 'You must select an order'
     C                   ELSE
     C                   EVAL      CRTDATE6 = SAVECRTDT6
     C                   EVAL      CRTDATE  = TOISO(CRTDATE6)
     C                   EVAL      CUSTNO   = SAVECUST
     C                   EVAL      INVNO    = SAVEINVNO
     c                   ENDIF

     C                   ENDDO
     C*------------------------
     C                   ENDSR


     C*=============================================================
     C*  Create a new order
     C*=============================================================
     C     NEWORD        BEGSR
     C*------------------------
     C                   IF        *IN03 or *IN12
     C                   LEAVESR
     C                   ENDIF

     C                   CLEAR                   INVENT3
     C                   CLEAR                   INVENT4C

     C                   DOU       MSG = *BLANKS

     C                   EXFMT     INVENT2
     C                   EVAL      MSG = *BLANKS

     C                   SELECT
     C                   WHEN      *IN03=*ON or *IN12=*ON
     C                   LEAVESR
     C                   ENDSL

     C                   IF        CUSTNO = 0
     C                   EVAL      MSG = 'You must type a customer +
     C                                    number'
     C                   ITER
     C                   ENDIF

     C     CUSTNO        CHAIN(N)  CUSTMAS                            10
     C                   IF        *IN10 = *ON
     C                   EVAL      MSG = 'Customer ' + %char(CUSTNO) +
     C                                   ' not found!'
     C                   ITER
     C                   ENDIF

     C                   ENDDO

     C     INVCTRL       KLIST
     C                   KFLD                    CKEY
     C                   KFLD                    CSUBKEY

     C                   EVAL      CKEY = 'INVNO'
     C                   EVAL      CSUBKEY = '*ONLY'

     C     INVCTRL       CHAIN     CTRLDTA                            10
     C                   IF        *IN10 = *ON
     c                   EVAL      CVALUE = 10000
     C                   ENDIF
     C                   EVAL      CVALUE = CVALUE + 1
     C                   IF        CVALUE > 9999990
     C                   EVAL      CVALUE = 1
     C                   ENDIF
     C   10              WRITE     CTRLDTAF
     C  N10              UPDATE    CTRLDTAF
     C                   EVAL      INVNO = CVALUE

     C                   EVAL      NEWORDER = 'Y'
     C*------------------------
     C                   ENDSR


     C*=============================================================
     C*  Load an order from the invoice files and/or custmas
     C*  If the order is new, default values are assigned.
     C*=============================================================
     C     LOADORD       BEGSR
     C*------------------------
     C                   IF        *IN03 or *IN12
     C                   LEAVESR
     C                   ENDIF

      *  Clear out any old order data
     C                   EVAL      SAVECUST = CUSTNO
     C                   EVAL      SAVEINVNO = INVNO
     C                   EVAL      SAVECRTDT6 = CRTDATE6

     C                   CLEAR                   INVENT3
     C                   CLEAR                   INVENT4C
     C                   CLEAR                   INVENT4F

     C                   EVAL      CUSTNO   = SAVECUST
     C                   EVAL      INVNO    = SAVEINVNO
     C                   EVAL      CRTDATE6 = SAVECRTDT6
     C                   EVAL      CRTDATE  = TOISO(SAVECRTDT6)

     C                   EVAL      RRN4 = 0
     C                   EVAL      HIGHRRN4 = 0
     C                   EVAL      LASTRRN4 = 0
     C                   EVAL      *IN60 = *ON
     C                   EVAL      *IN61 = *OFF
     C                   WRITE     INVENT4C
     C                   EVAL      *IN60 = *OFF

      *  Load customer details
     C     CUSTNO        CHAIN(N)  CUSTMAS                            10
     C                   IF        *IN10 = *ON
     C                   EVAL      MSG = 'Customer ' + %char(CUSTNO) +
     C                                   ' not found!'
     C                   EVAL      *IN12 = *ON
     C                   LEAVESR
     C                   ENDIF

      *  For new orders, copy customer details from custmas -> invoice
     C                   IF        NEWORDER = 'Y'
     C                   EVAL      DELNAME   = CMNAME
     C                   EVAL      DELCONT   = CMCONTACT
     C                   EVAL      DELSTREET = CMSTREET
     C                   EVAL      DELCITY   = CMCITY
     C                   EVAL      DELSTATE  = CMSTATE
     C                   EVAL      DELPOSTAL = CMPOSTAL
     C                   EVAL      DELCNTRY  = CMCOUNTRY
     C                   EVAL      BILNAME   = CMNAME
     C                   EVAL      BILSTREET = CMSTREET
     C                   EVAL      BILCITY   = CMCITY
     C                   EVAL      BILSTATE  = CMSTATE
     C                   EVAL      BILPOSTAL = CMPOSTAL
     C                   EVAL      BILCNTRY  = CMCOUNTRY
     C                   EVAL      CRTDATE   = %DEC(%DATE():*ISO)
     C                   EVAL      DELDATE   = CRTDATE
     C                   EVAL      CRTDATE6  = TOJOB(CRTDATE)
     C                   EVAL      DELDATE6  = CRTDATE6
     C                   ENDIF

      *  Terms message
     C                   SELECT
     C                   WHEN      CMTERMTYPE = 'N'
     C                   EVAL      TERMS = 'NET'
     C                   OTHER
     C                   EVAL      TERMS = 'IMMEDIATE'
     C                   ENDSL

      *  Reset calculated values
     C                   EVAL      LASTORD6 = TOJOB(CMLASTORD)
     C                   EVAL      LASTPAID6 = TOJOB(CMLASTPAID)
     C                   EVAL      SUBTOTAL = 0
     C                   EVAL      TOTALQTY = 0
     C                   EVAL      TOTAL = 0

      * Load existing order from database
     C                   IF        NEWORDER = 'N'

     C     INVHDRK1      KLIST
     C                   KFLD                    INVNO
     C                   KFLD                    CRTDATE

     C     INVHDRK1      CHAIN     INVHDR                             10
     C                   IF        *IN10 = *ON
     C                   EVAL      MSG = 'Invoice ' + %char(INVNO) +
     C                                   ' not found!'
     C                   EVAL      *IN12 = *ON
     C                   LEAVESR
     C                   ENDIF

     C                   EVAL      PODATE6 = TOJOB(PODATE)
     C                   EVAL      DELDATE6 = TOJOB(DELDATE)
     C                   EVAL      SUBTOTAL = 0
     C                   EVAL      TOTALQTY = 0
     C                   EVAL      TOTAL = 0

     C     INVHDRK1      SETLL     INVDET
     C     INVHDRK1      READE(N)  INVDET                                 10
     C                   DOW       *IN10 = *OFF

     C                   EVAL      SUBTOTAL = SUBTOTAL
     C                                      + %dech(QTY * PRICE: 7: 2)
     C                   EVAL      TOTALQTY = TOTALQTY + QTY

     C                   EVAL      RRN4 = RRN4 + 1
     C                   EVAL      *IN61 = *ON
     C                   WRITE     INVENT4S

     C     INVHDRK1      READE(N)  INVDET                                 10
     C                   ENDDO

     C                   EVAL      HIGHRRN4 = RRN4

     C                   ENDIF

      * Recalculate total
     C                   EVAL      TOTAL = SUBTOTAL + SHIPPING + TAX

      * Add some blank rows to subfile for user to enter new items into
     C                   EVAL      EMPTY = 0
     C                   EVAL      LASTRRN4 = HIGHRRN4 + 1
     C                   EXSR      ADDBLANKS
     C*------------------------
     C                   ENDSR


     C*=============================================================
     C*  This ensures that there are empty records on the items
     C*  screen to type new items into -- it adds blank rows.
     C*=============================================================
     C     ADDBLANKS     BEGSR
     C*------------------------
     C                   CLEAR                   INVENT4S
     C                   EVAL      RRN4 = HIGHRRN4

     C                   DOW       EMPTY < 5

     C                   EVAL      RRN4 = RRN4 + 1
     C                   EVAL      *IN61 = *ON
     C                   WRITE     INVENT4S

     C                   EVAL      EMPTY = EMPTY + 1
     C                   ENDDO

     C                   EVAL      HIGHRRN4 = RRN4
     C*------------------------
     C                   ENDSR


     C*=============================================================
     C*  This displays and checks the customer info screen
     C*=============================================================
     C     CUSTINFO      BEGSR
     C*------------------------
     C                   DOU       MSG = *BLANKS

     C                   EXFMT     INVENT3
     C                   EVAL      MSG = *BLANKS

     C                   IF        *IN03 or *IN12
     C                   UNLOCK    INVHDR                               10
     C                   LEAVESR
     C                   ENDIF

     C                   ENDDO
     C*------------------------
     C                   ENDSR


     C*=============================================================
     C*  This displays and checks the item information screen
     C*=============================================================
     C     ITEMS         BEGSR
     C*------------------------
     C                   DOU       MSG = *BLANKS
     C                             AND CHANGE = 'N'

     C                   IF        LASTRRN4 > HIGHRRN4
     C                             OR LASTRRN4 < 1
     C                   EVAL      NEXTRRN4 = 1
     C                   ELSE
     C                   EVAL      NEXTRRN4 = LASTRRN4
     C                   ENDIF

     C                   WRITE     INVENT4F
     C                   EXFMT     INVENT4C
     C                   READ      INVENT4F

     C                   EVAL      MSG = *BLANKS
     C                   EVAL      CHANGE = 'N'
     C                   EVAL      SUBTOTAL = 0
     C                   EVAL      TOTALQTY = 0
     C                   EVAL      EMPTY = 0

     C                   IF        *IN03 or *IN12
     C                   LEAVESR
     C                   ENDIF

     C                   READC     INVENT4S                               10
     C                   IF        *IN10 = *ON
     C                   EVAL      CHANGE = 'N'
     C                   ELSE
     C                   EVAL      CHANGE = 'Y'
     C                   ENDIF
     C                   IF        *IN62 = *ON
     C                   EVAL      CHANGE = 'Y'
     C                   ENDIF

     C                   IF        *IN04
     C                              AND LASTRRN4 >= 1
     C                              AND LASTRRN4 <= HIGHRRN4

     C                   CALL      'ITMINQR'
     C                   PARM                    PITEMNO
     C                   PARM                    CANCEL

     C                   IF        CANCEL = *OFF
     C     PITEMNO       CHAIN     ITEMMAS                            10
     C                   IF        *IN10 = *OFF
     C     LASTRRN4      CHAIN     INVENT4S                           10
     C                   IF        *IN10 = *OFF
     C                   EVAL      ITEMNO = IMITEMNO
     C                   EVAL      DESCR  = IMDESCR
     C                   EVAL      PRICE  = IMPRICE
     C                   EVAL      UOM    = IMUOM
     C                   EVAL      CHANGE = 'Y'
     C                   UPDATE    INVENT4S
     C                   ENDIF
     C                   ENDIF

     C                   ENDIF


     C                   ENDIF

     C     1             DO        HIGHRRN4      RRN4

     C     RRN4          CHAIN     INVENT4S                           10
     C                   IF        *IN10 = *ON
     C                   ITER
     C                   ENDIF

     C                   IF        ITEMNO = 0
     C                             AND DESCR = *BLANKS
     C                             AND QTY = 0
     C                             AND UOM = *BLANKS
     C                             AND PRICE = 0
     C                   EVAL      EMPTY = EMPTY + 1
     C                   ITER
     C                   ENDIF

     C     ITEMNO        CHAIN     ITEMMAS                            10
     C                   IF        *IN10 = *ON
     C                   EVAL      MSG = 'Item number ' + %char(ITEMNO)
     C                                 + ' not found!'
     C                   ITER
     C                   ENDIF

     C                   IF        PRICE = 0
     C                   EVAL      MSG = 'Missing price!'
     C                   EVAL      PRICE = IMPRICE
     C                   ENDIF
     C                   IF        UOM = *BLANKS
     C                   EVAL      MSG = 'Missing UOM!'
     C                   EVAL      UOM = IMUOM
     C                   ENDIF
     C                   IF        QTY = 0
     C                   EVAL      MSG = 'Missing Quantity!'
     C                   ENDIF
     C                   IF        DESCR = *BLANKS
     C                   EVAL      MSG = 'Missing Description!'
     C                   EVAL      DESCR = IMDESCR
     C                   ENDIF

     C                   IF        MSG = *BLANKS
     C                   IF        PRICE < IMMINPRC
     C                   EVAL      MSG = 'Price ' + %char(PRICE) + ' too low!'
     C                   ENDIF
     C                   IF        PRICE > IMMAXPRC
     C                   EVAL      MSG = 'Price ' + %char(PRICE) + ' too high!'
     C                   ENDIF
     C     UOM           CHAIN     UNITS                              10
     C                   IF        *IN10 = *ON
     C                   EVAL      MSG = 'Invalid Unit of Measure "'
     C                                 + UOM + '"'
     C                   ENDIF
     C                   ENDIF

     C                   MONITOR
     C                   EVAL      SUBTOTAL = SUBTOTAL
     C                                      + %dech(QTY * PRICE: 7: 2)
     C                   ON-ERROR
     C                   EVAL      MSG = 'Subtotal Calculation Error'
     C                   EVAL      SUBTOTAL = *HIVAL
     C                   ENDMON

     C                   MONITOR
     C                   EVAL      TOTALQTY = TOTALQTY + QTY
     C                   ON-ERROR
     C                   EVAL      MSG = 'Total Qty Calculation Error'
     C                   EVAL      TOTALQTY = *HIVAL
     C                   ENDMON

     C                   UPDATE    INVENT4S
     C                   ENDDO

     C                   MONITOR
     C                   EVAL      TOTAL = SUBTOTAL
     C                                   + SHIPPING
     C                                   + TAX
     C                   ON-ERROR
     C                   EVAL      MSG = 'Total Calculation Error'
     C                   EVAL      TOTAL = *HIVAL
     C                   ENDMON

     C                   IF        EMPTY < 5
     C                   EXSR      ADDBLANKS
     C                   EVAL      CHANGE = 'Y'
     C                   ENDIF

     C                   IF        MSG=*BLANKS and TOTALQTY = 0
     C                   EVAL      MSG = 'Enter some items onto this invoice!'
     C                   ENDIF

     C                   ENDDO
     C*------------------------
     C                   ENDSR


     C*=============================================================
     C*  This saves the invoice to disk
     C*=============================================================
     C     SAVEORD       BEGSR
     C*------------------------
     C                   IF        NEWORDER = 'Y'
     C                   EVAL      CRTDATE6 = %dec(%date():*jobrun)
     C                   ENDIF

     C                   EVAL      PODATE  = TOISO(PODATE6)
     C                   EVAL      DELDATE = TOISO(DELDATE6)
     C                   EVAL      CRTDATE = TOISO(CRTDATE6)
     C                   EVAL      INVDATE = CRTDATE
     C                   EVAL      MYLINENO = 0

     C     INVHDRK2      KLIST
     C                   KFLD                    INVNO
     C                   KFLD                    CRTDATE

     C                   DOU       *IN10 = *ON
     C     INVHDRK2      DELETE    INVDETF                            10
     C                   ENDDO

     C     1             DO        HIGHRRN4      RRN4

     C     RRN4          CHAIN     INVENT4S                           10
     C                   IF        *IN10 = *ON
     c                             OR QTY = 0
     C                   ITER
     C                   ENDIF

     C                   EVAL      MYLINENO = MYLINENO + 1
     C                   EVAL      LINENO = MYLINENO
     C                   EVAL      CRTDATE = TOISO(CRTDATE6)
     C                   WRITE     INVDETF

     C                   ENDDO

     C                   IF        NEWORDER = 'Y'
     C                   WRITE     INVHDRF
     C                   ELSE
     C                   UPDATE    INVHDRF
     C                   ENDIF

     C     CUSTNO        CHAIN     CUSTMAS                            1011
     C                   IF        *IN10 = *OFF and *IN11 = *OFF
     C                   EVAL      CMLASTORD = %dec(%date():*ISO)
     C                   UPDATE    CUSTMASF
     C                   ENDIF

     C                   EVAL      STEP = 0
     C*------------------------
     C                   ENDSR


     C*=============================================================
     C*  Delete an invoice (if unpaid, undelivered)
     C*=============================================================
     C     DELETEINV     BEGSR
     C*------------------------
     c                   EVAL      CONFIRM = 'N'

     C                   DOU       MSG = *blanks

     C                   EXFMT     INVENT5
     C                   EVAL      MSG = *blanks

     C                   IF        *in03 or *in12 or CONFIRM='N'
     C                   EVAL      MSG = 'Delete of ' + %char(SAVEINVNO)
     C                                 + ' was cancelled.'
     C                   eval      *IN03 = *OFF
     C                   eval      *IN12 = *OFF
     C                   LEAVESR
     C                   ENDIF

     C                   EVAL      CRTDATE = TOISO(SAVECRTDT6)
     C     INVHDRK3      KLIST
     C                   KFLD                    SAVEINVNO
     C                   KFLD                    CRTDATE

     C                   IF        CONFIRM <> 'Y'
     C                   EVAL      MSG = 'You must choose Y (=yes) or N (=no)'
     C                   ITER
     C                   ENDIF

     C     INVHDRK3      CHAIN     INVHDR                             1011
     C                   IF        *IN11 = *ON
     C                   EVAL      MSG = 'Invoice ' + %char(SAVEINVNO)
     C                                 + ' is locked by another job'
     C                   ENDIF
     C                   IF        *IN10 = *ON
     C                   EVAL      MSG = 'Invoice ' + %char(SAVEINVNO)
     C                                 + ' not found (already deleted?)'
     C                   ENDIF

     C                   ENDDO

     C                   DOU       *IN10 = *ON
     C     INVHDRK3      DELETE    INVDETF                            10
     C                   ENDDO
     C                   DELETE    INVHDRF

     C                   EVAL      STEP = 0
     C*------------------------
     C                   ENDSR


     C*=============================================================
     C*  Edit the footer message
     C*=============================================================
     C     FOOTERMSG     BEGSR
     C*------------------------
     C                   DOU       MSG = *BLANKS

     C                   EXFMT     INVENT7
     C                   EVAL      MSG = *BLANKS

     C                   IF        *IN03 or *IN12
     C                   LEAVESR
     C                   ENDIF

     C                   ENDDO
     C*------------------------
     C                   ENDSR


     C*=============================================================
     C*  Mark an invoice paid
     C*=============================================================
     C     PAYINV        BEGSR
     C*------------------------
     c                   EVAL      CONFIRM = 'N'

     C                   DOU       MSG = *blanks

     C                   EXFMT     INVENT6
     C                   EVAL      MSG = *blanks

     C                   IF        *in03 or *in12 or CONFIRM='N'
     C                   EVAL      MSG = 'Mark paid of ' + %char(SAVEINVNO)
     C                                 + ' was cancelled.'
     C                   eval      *IN03 = *OFF
     C                   eval      *IN12 = *OFF
     C                   LEAVESR
     C                   ENDIF

     C                   EVAL      CRTDATE = TOISO(SAVECRTDT6)
     C     INVHDRK4      KLIST
     C                   KFLD                    SAVEINVNO
     C                   KFLD                    CRTDATE

     C                   IF        CONFIRM <> 'Y'
     C                   EVAL      MSG = 'You must choose Y (=yes) or N (=no)'
     C                   ITER
     C                   ENDIF

     C     INVHDRK4      CHAIN     INVHDR                             1011
     C                   IF        *IN11 = *ON
     C                   EVAL      MSG = 'Invoice ' + %char(SAVEINVNO)
     C                                 + ' is locked by another job'
     C                   ENDIF
     C                   IF        *IN10 = *ON
     C                   EVAL      MSG = 'Invoice ' + %char(SAVEINVNO)
     C                                 + ' not found (already deleted?)'
     C                   ENDIF

     C                   ENDDO

     C                   EVAL      PAIDDATE = %dec(%date():*ISO)
     C                   UPDATE    INVHDRF

     C     SAVECUST      CHAIN     CUSTMAS                            10
     C                   IF        *IN10 = *OFF
     C                   EVAL      CMLASTPAID = %dec(%date():*ISO)
     C                   UPDATE    CUSTMASF
     C                   ENDIF

     C                   EVAL      STEP = 0
     C*------------------------
     C                   ENDSR


     C*=============================================================
     C* TOJOB(): SUBPROCEDURE TO CONVERT A DATE TO JOB FORMAT
     C*=============================================================
     P TOJOB           B
     D                 PI             6S 0
     D   DTISO                        8S 0 value

     D RETVAL          s              6s 0
     D RDATE           s               D

     C                   select
     C                   when      DTISO = 99999999
     C                   eval      RETVAL = 999999
     C                   when      DTISO = 0
     C                   eval      RETVAL = 0
     C                   other
     C                   EVAL      RDATE = %DATE(DTISO:*ISO)
     C                   EVAL      RETVAL = %DEC(RDATE:*JOBRUN)
     C                   endsl

     C                   RETURN    RETVAL
     P                 E


     C*=============================================================
     C* TOJOB(): SUBPROCEDURE TO CONVERT A DATE TO ISO FORMAT
     C*=============================================================
     P TOISO           B
     D                 PI             8S 0
     D   DTJOB                        6S 0 value

     D RETVAL          s              8s 0
     D RDATE           s               D

     C                   select
     C                   when      DTJOB = 999999
     C                   eval      RETVAL = 99999999
     C                   when      DTJOB = 0
     C                   eval      RETVAL = 0
     C                   other
     C                   EVAL      RDATE = %DATE(DTJOB:*JOBRUN)
     C                   EVAL      RETVAL = %DEC(RDATE:*ISO)
     C                   endsl

     C                   RETURN    RETVAL
     P                 E
