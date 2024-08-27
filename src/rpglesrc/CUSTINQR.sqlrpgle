**free
ctl-opt option(*srcstmt:*nodebugio);

dcl-f CUSTINQD workstn indds(DSPF) sfile(SFL:RRN);

dcl-ds DSPF qualified;
  Exit       ind pos( 3);
  Refresh    ind pos( 5);
  Cancel     ind pos(12);
  UnlockKey  ind pos(21);
  UnlockCust ind pos(40);
  StopInput  ind pos(41);
  SFLCLR     ind pos(50);
  SFLDSP     ind pos(51);
end-ds;  

dcl-s RRN        packed(4: 0);
dcl-s recsLoaded packed(4: 0);
dcl-s selCustNo  packed(4: 0);
dcl-s parmCount  int(10);

dcl-pi *n;
  selCustNo_in zoned(4: 0);
end-pi;

exec SQL set option naming=*sys, commit=*none;

parmCount = %PARMS;
if parmCount >= 1;
  selCustNo = selCustNo_in;
endif;

loadCustomerList();
if showCustomerList(selCustNo) = *off;
  if parmCount >= 1;
    selCustNo_in = selCustNo;
  else;
    snd-msg *info 'Selected cust ' + %char(selCustNo);
  endif;
endif;

*inlr = *on;


dcl-proc loadCustomerList;

  DSPF.SFLCLR = *ON;
  DSPF.SFLDSP = *OFF;
  write CTL;
  DSPF.SFLCLR = *OFF;
  RRN = 0;
  recsLoaded = 0;

  exec SQL declare loadList cursor for
    select custno, name, contact
      from CUSTMAS
    order by custno;

  exec SQL open loadList;
  exec SQL fetch next from loadList into :CUSTNUMB, :CUSTNAME, :CUSTCONT;
  rrn = 0;
  lastRRN = 0;

  dow %subst(sqlstt:1:2)='00' or %subst(sqlstt:1:2)='01';
    Opt = ' ';
    if selCustNo<>0 and selCustNo=CUSTNUMB;
      Opt = '1';
    endif;
    rrn += 1;
    recsLoaded += 1;
    write SFL;
    exec SQL fetch next from loadList into :CUSTNUMB, :CUSTNAME, :CUSTCONT;
  enddo;

  exec SQL close loadList;

  if recsLoaded > 0;
    DSPF.SFLDSP = *ON;
  endif;

end-proc;  

dcl-proc showCustomerList;

  dcl-pi *n ind;
    selCustNo packed(4: 0);
  end-pi;

  dcl-s Cancel ind inz(*off);
  dcl-s Repeat ind inz(*on);

  dow Repeat = *ON;

    if lastRRN > 0 and lastRRN <= recsLoaded;
      nextRRN = lastRRN;
    else;
      nextRRN = 1;
    endif;

    write FTR;
    exfmt CTL;
    msg = ' ';

    if DSPF.Exit=*ON or DSPF.Cancel=*On;
      Repeat = *OFF;
      Cancel = *on;
      leave;
    endif;

    selCustNo = 0;

    for RRN = 1 to recsLoaded;

      chain RRN SFL;
      if not %found;
        iter;
      endif;

      select;
      when Opt = '1' and selCustNo = 0;
        selCustNo = CustNumb;
        Repeat = *OFF;
      when Opt = '2';
        if EditCustomer(CustNumb) = *on;
          Repeat = *OFF;
          Cancel = *ON;
          return *on;
        else;
          DSPF.Refresh = *ON;
        endif;
      endsl;

      Opt = ' ';
      update SFL;
       
    endfor;

    if DSPF.Refresh = *ON;
      Repeat = *ON;
      loadCustomerList();
      iter;
    endif;

  enddo;

  return Cancel;

end-proc;

dcl-proc editCustomer;

  dcl-pi *n ind;
    CustNo packed(4: 0) const;
  end-pi;

  dcl-ds ORIG       likerec(EDITCUST:*ALL);
  dcl-ds SCRN       likerec(EDITCUST:*ALL);
  dcl-s  Repeat ind inz(*ON);

  if loadCustomer(CustNo: ORIG) = *OFF;
    return *OFF;
  endif;

  eval-corr SCRN = ORIG;

  dow Repeat = *ON;

    exfmt EDITCUST SCRN;

    if DSPF.Exit=*ON or DSPF.Cancel=*ON;
      Repeat = *OFF;
      return *ON;
    endif;

    if DSPF.UnlockKey = *ON;
      DSPF.UnlockCust = not DSPF.UnlockCust;
      Repeat = *ON;
      iter;
    endif;

    if updateCustomer(ORIG:SCRN) = *on;
      Repeat = *off;
    else;
      msg = 'Update failed';
      Repeat = *on;
    endif;

  enddo;

  return *off;
end-proc;

dcl-proc loadCustomer;

  dcl-pi *N ind;
    CustNo packed(4: 0) value;
    RTNREC likerec(EDITCUST:*ALL);
  end-pi;

  dcl-ds REC qualified;
    CUSTNO    packed(4: 0);
    NAME      char(30);
    CONTACT   char(30);
    PHONE     char(15);
    EMAIL     char(63);
    BILCONT   char(30);
    BILPHONE  char(15);
    BILEMAIL  char(63);
    STREET    char(30);
    CITY      char(20);
    STATE     char( 2);
    POSTAL    char(13);
    COUNTRY   char(30);
    CRTDATE   char(10);
    LASTORD   char(10);
    LASTPAID  char(10);
    TERMTYPE  char( 1);
    TERMDAYS  packed(3: 0);
    ACCTREP   char( 3);
    TERR      char( 1);
    CHANNEL   char( 1);
  end-ds;
    

  clear REC;

  exec SQL
    select CUSTNO,
           NAME,
           CONTACT,
           PHONE,
           EMAIL,
           BILCONT,
           BILPHONE,
           BILEMAIL,
           STREET,
           CITY,
           STATE,
           POSTAL,
           COUNTRY,
           case when CRTDATE=0  then ' ' else DIGITS(CRTDATE)  end,
           case when LASTORD=0  then ' ' else DIGITS(LASTORD)  end,
           case when LASTPAID=0 then ' ' else DIGITS(LASTPAID) end,
           TERMTYPE,
           TERMDAYS,
           ACCTREP,
           TERR,
           CHANNEL
      into :REC
      from CUSTMAS
     where CUSTNO = :CustNo;          

  if %subst(sqlstt:1:2)='00' or %subst(sqlstt:1:2)='01';
    eval-corr RTNREC = REC;
    if REC.CRTDATE <> ' ';
      RTNREC.CRTDATE = %CHAR(%DATE(REC.CRTDATE:*ISO0): *USA);
    endif;
    if REC.LASTORD <> ' ';
      RTNREC.LASTORD = %CHAR(%DATE(REC.LASTORD:*ISO0): *USA);
    endif;
    if REC.LASTPAID <> ' ';
      RTNREC.LASTPAID = %CHAR(%DATE(REC.LASTPAID:*ISO0): *USA);
    endif;
    return *on;
  else;
    return *off;
  endif;

end-proc;


dcl-proc updateCustomer;

  dcl-pi *N ind;
    ORIGREC likerec(EDITCUST:*ALL) const;
    UPDREC  likerec(EDITCUST:*ALL) const;
  end-pi;

  dcl-ds UPD qualified;
    CUSTNO    packed(4: 0);
    NAME      char(30);
    CONTACT   char(30);
    PHONE     char(15);
    EMAIL     char(63);
    BILCONT   char(30);
    BILPHONE  char(15);
    BILEMAIL  char(63);
    STREET    char(30);
    CITY      char(20);
    STATE     char( 2);
    POSTAL    char(13);
    COUNTRY   char(30);
    CRTDATE   char(10);
    LASTORD   char(10);
    LASTPAID  char(10);
    TERMTYPE  char( 1);
    TERMDAYS  packed(3: 0);
    ACCTREP   char( 3);
    TERR      char( 1);
    CHANNEL   char( 1);
  end-ds;

  dcl-ds ORIG likeds(UPD);
  dcl-s CRTDATE2 packed(8: 0) inz(0);
  dcl-s LASTORD2 packed(8: 0) inz(0);
  dcl-s LASTPAID2 packed(8: 0) inz(0);

  if UPD.CRTDATE <> ' ';
    CRTDATE2 = %dec(%date(UPD.CRTDATE:*USA): *ISO);
  endif;
  if UPD.LASTORD <> ' ';
    LASTORD2 = %dec(%date(UPD.LASTORD:*USA): *ISO);
  endif;
  if UPD.LASTPAID <> ' ';
    LASTPAID2 = %dec(%date(UPD.LASTPAID:*USA): *ISO);
  endif;
  
  eval-corr ORIG = ORIGREC;
  eval-corr UPD  = UPDREC;
  
  exec SQL
    update CUSTMAS
      set CUSTNO     = case when :ORIG.CUSTNO <> :UPD.CUSTNO
                       then :UPD.CUSTNO else CUSTNO end,
          NAME       = case when :ORIG.NAME <> :UPD.NAME
                       then :UPD.NAME else NAME end,
          CONTACT    = case when :ORIG.CONTACT <> :UPD.CONTACT
                       then :UPD.CONTACT else CONTACT end,
          PHONE      = case when :ORIG.PHONE <> :UPD.PHONE
                       then :UPD.PHONE else PHONE end,
          EMAIL      = case when :ORIG.EMAIL <> :UPD.EMAIL
                       then :UPD.EMAIL else EMAIL end,
          BILCONT    = case when :ORIG.BILCONT <> :UPD.BILCONT
                       then :UPD.BILCONT else BILCONT end,
          BILPHONE   = case when :ORIG.BILPHONE <> :UPD.BILPHONE
                       then :UPD.BILPHONE else BILPHONE end,
          BILEMAIL   = case when :ORIG.BILEMAIL <> :UPD.BILEMAIL
                       then :UPD.BILEMAIL else BILEMAIL end,
          STREET     = case when :ORIG.STREET <> :UPD.STREET
                       then :UPD.STREET else STREET end,
          CITY       = case when :ORIG.CITY <> :UPD.CITY
                       then :UPD.CITY else CITY end,
          STATE      = case when :ORIG.STATE <> :UPD.STATE
                       then :UPD.STATE else STATE end,
          POSTAL     = case when :ORIG.POSTAL <> :UPD.POSTAL
                       then :UPD.POSTAL else POSTAL end,
          COUNTRY    = case when :ORIG.COUNTRY <> :UPD.COUNTRY
                       then :UPD.COUNTRY else COUNTRY end,
          CRTDATE    = case when :ORIG.CRTDATE <> :UPD.CRTDATE
                       then :CRTDATE2 else CRTDATE end,
          LASTORD    = case when :ORIG.LASTORD <> :UPD.LASTORD
                       then :LASTORD2 else LASTORD end,
          LASTPAID   = case when :ORIG.LASTPAID <> :UPD.LASTPAID
                       then :LASTPAID2 else LASTPAID end,
          TERMTYPE   = case when :ORIG.TERMTYPE <> :UPD.TERMTYPE
                       then :UPD.TERMTYPE else TERMTYPE end,
          TERMDAYS   = case when :ORIG.TERMDAYS <> :UPD.TERMDAYS
                       then :UPD.TERMDAYS else TERMDAYS end,
          ACCTREP    = case when :ORIG.ACCTREP <> :UPD.ACCTREP
                       then :UPD.ACCTREP else ACCTREP end,
          TERR       = case when :ORIG.TERR <> :UPD.TERR
                       then :UPD.TERR else TERR end,
          CHANNEL    = case when :ORIG.CHANNEL <> :UPD.CHANNEL
                       then :UPD.CHANNEL else CHANNEL end
      where CUSTNO = :ORIG.CUSTNO;

  if %subst(sqlstt:1:2)='00' or %subst(sqlstt:1:2)='01';
    return *on;
  else;
    return *off;
  endif;

end-proc;
