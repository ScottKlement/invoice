**FREE

///
// INVOICE - The Invoice Service Program
//
// Contains the business model to implement invoice support
//
//  @author Scott Klement
//  @date   April 13 2023
//
// *> ign: DLTMOD &O/&ON
// *> CRTSQLRPGI OBJ(&O/&ON) OBJTYPE(*MODULE) SRCFILE(&L/&F) DBGVIEW(&DV) TGTRLS(&RLS) -
// *>             COMMIT(*NONE) OPTION(*XREF *SYS *EVENTF) RPGPPOPT(*LVL2)
// *> CRTSRVPGM SRVPGM(&O/&ON) MODULE(&O/&ON) SRCFILE(&L/QSRVSRC) -
// *>           TGTRLS(&RLS)
// *> ign: DLTMOD &O/&ON
//
///

ctl-opt nomain option(*noshowcpy:*nodebugio:*srcstmt);
/if defined(*V7R3M0)
ctl-opt debug(*constants: *retval);
/endif

dcl-f CTRLDTA disk keyed usage(*input:*output:*update) usropn;

dcl-ds PSDS psds qualified;
  library char(10) pos(81);
end-ds;

/copy invoice_h

dcl-pr QCMDEXC extpgm('QCMDEXC');
  cmd char(2000) const;
  len packed(15: 5) const;
  igc char(3) const options(*nopass);
end-pr;

dcl-s init_done ind inz(*off);

dcl-ds gINV qualified;
  hdr   likeds(INVOICE_HEADER_t);
  count int(10);
  det   likeds(INVOICE_DETAIL_t) dim(999);
end-ds;

dcl-ds gERR qualified;
  msgid     char(7);
  msgdta    char(32767);
  msgdtalen int(10);
end-ds;


///
//  Initialize()
//    This is called the first time this service program
//    has any of it's procedures called -- can be used for
//    any sort of first-time processing.
//
//  @info Sets global init_done indicator to prevent running twice.
///

dcl-proc Initialize;

  dcl-pi *n;
  end-pi;

  dcl-pr CEE4RAGE;
    procedure   pointer(*proc) const;
    feedback    char(12) options(*omit);
  end-pr;

  if init_done;
    return;
  endif;

  if not %open(CTRLDTA);
    open CTRLDTA;
  endif;

  CEE4RAGE(%paddr(Cleanup): *omit);
  init_done = *on;

end-proc;


///
// Clean Up Service Program
//   This is called when the service program is to be cleaned
//   up. Normally this is when the activation group is
//   terminated (but could potentially be called from within
//   if we programmatically want to clean things up.)
//
//   @param (input/opt) activation group mark
//   @param (input/opt) reason for termination
//   @param (output/opt) system return code
//   @param (output/opt) user return code
//
// @info Resets the global init_done indicator.
///

dcl-proc Cleanup;

  dcl-pi *n;
    agMark  uns(10)  const options(*nopass);
    reason  uns(10)  const options(*nopass);
    sysrc   uns(10)  options(*nopass);
    userrc  uns(10)  options(*nopass);
  end-pi;

  close *all;
  init_done = *off;
end-proc;


///
// Create New Invoice
//    Create a new invoice in memory by gathering
//    default values from custmas, ctrlmas, etc.
//
//   @param (input) customer number to create the invoice for
//   @param (output) invoice header details
//
//  @return 1=SUCCESS, or 0=FAIL
///

dcl-proc invoice_create export;

  dcl-pi *n int(10);
    custno  zoned(4: 0) const;
    header  likeds(INVOICE_header_t) options(*omit:*nopass);
  end-pi;

  dcl-ds CD  likerec(CTRLDTAF:*ALL);

  dcl-ds CM qualified;
    name     like(CUSTMAS_t.name     );
    contact  like(CUSTMAS_t.contact  );
    phone    like(CUSTMAS_t.phone    );
    bilcont  like(CUSTMAS_t.bilcont  );
    street   like(CUSTMAS_t.street   );
    city     like(CUSTMAS_t.city     );
    state    like(CUSTMAS_t.state    );
    postal   like(CUSTMAS_t.postal   );
    country  like(CUSTMAS_t.country  );
    termtype like(CUSTMAS_t.termtype );
    termdays like(CUSTMAS_t.termdays );
    acctrep  like(CUSTMAS_t.acctrep  );
    terr     like(CUSTMAS_t.terr     );
    channel  like(CUSTMAS_t.channel  );
    lastord  like(CUSTMAS_t.lastord  );
    lastpaid like(CUSTMAS_t.lastpaid );
  end-ds;

  dcl-ds INV1001 qualified;
    custno packed(4: 0);
    state  char(5);
  end-ds;

  Initialize();

  clear gINV;

  exec SQL
    select name, contact, phone, bilcont, street, city, state,
           postal, country, termtype, termdays, acctrep, terr,
           channel, lastord, lastpaid
      into :CM
      from CUSTMAS
     where custno = :custno;

  if %subst(sqlstt:1:2)<>'00' and %subst(sqlstt:1:2)<>'01';
    INV1001.custno = custno;
    INV1001.state  = sqlstt;
    setError('INV1001': INV1001: %size(INV1001));
    return FAIL;
  endif;

  eval-corr gINV.hdr = CM;

  gINV.hdr.custno    = custno;
  gINV.hdr.delname   = CM.name;
  gINV.hdr.delcont   = CM.contact;
  gINV.hdr.delstreet = CM.street;
  gINV.hdr.delcity   = CM.city;
  gINV.hdr.delstate  = CM.state;
  gINV.hdr.delcntry  = CM.country;

  gINV.hdr.bilname   = CM.name;
  gINV.hdr.bilcont   = CM.bilcont;
  gINV.hdr.bilstreet = CM.street;
  gINV.hdr.bilcity   = CM.city;
  gINV.hdr.bilstate  = CM.state;
  gINV.hdr.bilcntry  = CM.country;

  gINV.hdr.deldate = %dec(%date() + %days(7):*iso);
  gINV.hdr.crtdate = %dec(%date():*iso);
  gINV.hdr.invdate = gINV.hdr.crtdate;
  invoice_getTermsMsg(CM.termtype: CM.termdays: gINV.hdr.termsmsg);

  CHAIN ('INVNO':'*ONLY') CTRLDTA CD;
  if not %found;
    CD.CKEY = 'INVNO';
    CD.CSUBKEY = '*ONLY';
    CD.CVALUE = 10000;
    WRITE CTRLDTAF CD;
  else;
    CD.CVALUE += 1;
    if CD.CVALUE > 9999990;
      CD.CVALUE = 1;
    endif;
    UPDATE CTRLDTAF CD;
  endif;

  gINV.hdr.invno = CD.CVALUE;

  if %parms >= 2 and %addr(header)<>*null;
    eval-corr header = gINV.hdr;
  endif;

  return SUCCESS;

end-proc;


///
//  Load/Return Invoice Header
//    returns the header details.
//
//  @param (input) invoice number to load
//  @param (input/opt) create date of invoice to load. If
//            not given, a matching invoice of any crtdate will
//            be loaded.
//  @param (output/opt) returned invoice header info.
//
//  @return SUCCESS or FAIL
///

dcl-proc invoice_getHeader export;

  dcl-pi *n int(10);
    invno   like(INVHDR_t.invno) const;
    crtdate date(*iso) const options(*omit:*nopass);
    header  likeds(INVOICE_header_t) options(*omit:*nopass);
  end-pi;

  dcl-ds hdr likeds(INVOICE_HEADER_t);
  dcl-ds det likeds(INVOICE_DETAIL_t);
  dcl-s crtdate8 like(INVHDR_t.crtdate) inz(0);

  dcl-ds INV1002 qualified;
    invno    packed(7: 0);
    crtdate  like(INVHDR_t.crtdate);
    state    char(5);
  end-ds;

  Initialize();

  clear gINV;

  if %parms >= 2 and %addr(crtdate)<>*NULL;
    crtdate8 = %dec(crtdate:*iso);
  endif;

  //--------------------------------------------------
  // load header data into memory
  //--------------------------------------------------

  exec SQL
    select h.INVNO, h.CRTDATE, h.CUSTNO, h.DELDATE, h.INVDATE, h.PAIDDATE,
           h.CUSTPO, h.PODATE,
           h.DELNAME, h.DELCONT, h.DELSTREET, h.DELCITY, h.DELSTATE, h.DELPOSTAL, h.DELCNTRY,
           c.PHONE,
           h.BILNAME, h.BILCONT, h.BILSTREET, h.BILCITY, h.BILSTATE, h.BILPOSTAL, h.BILCNTRY,
           c.BILPHONE,
           h.MSG1, h.MSG2, h.MSG3,
           h.WEIGHT, h.SUBTOTAL, h.SHIPPING, h.TAX, h.TOTAL,
           c.LASTORD, c.LASTPAID, c.TERMTYPE, c.TERMDAYS, '', c.ACCTREP, c.TERR, c.CHANNEL
      into :hdr
      from INVHDR h
      join CUSTMAS c on h.CUSTNO = c.CUSTNO
     where h.INVNO = :invno
               and (:crtdate8 = 0 or h.CRTDATE = :crtdate8)
       fetch first 1 rows only;

  if %subst(sqlstt:1:2)<>'00' and %subst(sqlstt:1:2)<>'01';
    INV1002.invno   = invno;
    INV1002.crtdate = crtdate8;
    INV1002.state   = sqlstt;
    setError('INV1002': INV1002: %size(INV1002));
    return FAIL;
  endif;

  //--------------------------------------------------
  // Calculate fields for header
  //--------------------------------------------------

  crtdate8 = hdr.crtdate;
  eval-corr gINV.hdr = hdr;
  invoice_getTermsMsg(hdr.termtype: hdr.termdays: hdr.termsmsg);
  gINV.count = 0;


  //--------------------------------------------------
  // Load details into memory
  //--------------------------------------------------

  exec SQL declare C1 cursor for
    select d.INVNO, d.LINENO, d.ITEMNO, d.PRODUCT, d.UOM, d.DESCR, d.PRICE, d.QTY,
           d.WGTLBS,
           (select c.UNCODE3 from UNITS c where UNCODE = d.UOM) as UOM3,
           i.MINQTY, i.MINPRC, i.MAXPRC
      from INVDET d
      join ITEMMAS i on d.ITEMNO = i.ITEMNO
     where d.INVNO = :invno and d.CRTDATE = :crtdate8
  order by d.LINENO;

  exec SQL open C1;
  exec SQL fetch next from C1 into :det;

  dow %subst(sqlstt:1:2)='00' or %subst(sqlstt:1:2)='01';
    gINV.count += 1;
    eval-corr gINV.det(gINV.count) = det;
    exec SQL fetch next from C1 into :det;
  enddo;

  exec SQL close C1;


  //--------------------------------------------------
  // if caller wanted to return the header, do it.
  //--------------------------------------------------

  if %parms >= 3 and %addr(header) <> *null;
    eval-corr header = gINV.hdr;
  endif;

  return SUCCESS;

end-proc;


///
// Retrieve the details (line items) of an invoice
//
//  @info It is assumed that you will call this immediately following
//        invoice_getHeader(), as such this will return the same invoice
//        that invoice_getHeader() loaded unless the invno/crtdate
//        doesn't match.
//
//        When invno/crtdate do not match the one in memory, this
//        will call invoice_getHeader() under the covers to change the
//        invoice loaded in memory.
//
//        if you wish to force a reload of the invoice, call
//        invoice_getHeader() before this.
//
//
//  @param (input) invoice number of invoice details to retrieve
//  @param (input/opt) creation date of invoice. if not given,
//           any invoice matching the invno will be returned.
//  @param (output/opt) array of line items on invoice
//  @param (input/opt) maximum number of array elements in
//                the 'detail' parm (or 999 if not given)
//
//  @return the number of detail items loaded
//          or FAIL upon error.
///

dcl-proc invoice_getDetail export;

  dcl-pi *n int(10);
    invno   like(INVHDR_t.invno) const;
    crtdate date(*iso) const options(*omit);
    detail  likeds(INVOICE_detail_t)
            dim(999) options(*omit:*nopass:*varsize);
    detelem int(10) const options(*omit:*nopass);
  end-pi;

  dcl-s crtdate8 like(INVHDR_t.crtdate);
  dcl-s maxelem int(10) inz(%elem(detail));
  dcl-s i int(10);

  Initialize();

  if %parms >= 2 and %addr(crtdate)<>*null;
    crtdate8 = %dec(crtdate:*iso);
  else;
    crtdate8 = gINV.hdr.crtdate;
  endif;

  if %parms >= 4 and %addr(detelem)<>*null;
    maxelem = detelem;
  endif;

  if invno <> gINV.hdr.invno or crtdate8 <> gINV.hdr.crtdate;
    if invoice_getHeader(invno:crtdate:*omit) = FAIL;
      return FAIL;
    endif;
  endif;

  if %parms >= 3 and %addr(detail) <> *null;

    for i = 1 to gINV.count;
      if i <= maxelem;
        eval-corr detail(i) = gINV.det(i);
      endif;
    endfor;

  endif;

  return gINV.count;

end-proc;


///
// invoice_openList():
//   Opens a (filtered) list of invoices
//
// @param (input/opt) include paid invoices in the list?
//                    default = all invoices included.
// @param (input/opt) start of date range of invoice dates
//                    to include. default=beginning of time
// @param (input/opt) end of date range. default=end of time
// @param (input/opt) customer number to include
//                    default=all customers
// @return SUCCESS or FAIL
///

dcl-proc invoice_openList export;

  dcl-pi *n int(10);
    incPaid   ind          const options(*omit:*nopass);
    startDate date(*iso)   const options(*omit:*nopass);
    endDate   date(*iso)   const options(*omit:*nopass);
    custno    like(INVHDR_t.custno) const options(*omit:*nopass);
  end-pi;

  dcl-s CheckPaid char(1) inz('Y');
  dcl-s CheckCust packed(4: 0) inz(0);
  dcl-s strDate8  packed(8: 0) inz(0);
  dcl-s endDate8  packed(8: 0) inz(99991231);

  dcl-ds INV1003 qualified;
    state char(5);
  end-ds;

  if %parms >= 1 and %addr(incPaid) <> *null;
    if incPaid=*ON;
      CheckPaid='N';
    endif;
  endif;

  if %parms >= 2 and %addr(startDate) <> *null;
    strDate8 = %dec(startDate:*iso);
  endif;

  if %parms >= 3 and %addr(endDate) <> *null;
    endDate8 = %dec(endDate:*iso);
  endif;

  if %parms >= 4 and %addr(custno) <> *null;
    CheckCust = custno;
  endif;

  Initialize();

  exec sql declare C2 cursor for
          select invno, crtdate
            from INVHDR
           where (:CheckPaid = 'N' or paiddate = 0)
             and (:CheckCust = 0   or custno = :CheckCust)
             and invdate between :strDate8 and :endDate8
           order by crtdate desc, invno;

  exec sql open C2;

  if %subst(sqlstt:1:2)<>'00' and %subst(sqlstt:1:2)<>'01';
    INV1003.state = sqlstt;
    setError('INV1003': INV1003: %size(INV1003));
    return FAIL;
  endif;

  return SUCCESS;
end-proc;


///
//  invoice_readList():
//     Read the next invoice from the list
//
//  @info This replaces the invoice currently loaded into this model
//        subsequent calls to getDetail, setHeader, setDetail, save,
//        will affect this loaded invoice.
//
// @param (output/opt) invoice header info returned.
//
// @return FAIL upon error or end of list
//           SUCCESS otherwise
///

dcl-proc invoice_readList export;

  dcl-pi *n int(10);
    header  likeds(INVOICE_header_t) options(*omit:*nopass);
  end-pi;

  dcl-ds C2 qualified;
    invno   like(INVHDR_t.INVNO);
    crtdate like(INVHDR_t.CRTDATE);
  end-ds;

  dcl-ds INV1004 qualified;
    state char(5);
  end-ds;

  exec sql fetch next from C2 into :C2;
  if %subst(sqlstt:1:2)<>'00' and %subst(sqlstt:1:2)<>'01';
    INV1004.state = sqlstt;
    setError('INV1004': INV1004: %size(INV1004));
    return FAIL;
  endif;

  if %parms >= 1 and %addr(header)<>*null;
    return invoice_getHeader(C2.invno: %date(C2.crtdate:*iso): header);
  else;
    return invoice_getHeader(C2.invno: %date(C2.crtdate:*iso): *omit);
  endif;

  return SUCCESS;
end-proc;


///
// invoice_closeList():
//   close invoice list.  Not much else to say :-)
///

dcl-proc invoice_closeList export;
  dcl-pi *n;
  end-pi;
  exec SQL close C2;
  return;
end-proc;


///
// invoice_setHeader():
//   Set the header information of an invoice.
//
//   @info This sets the header info within memory in this model.
//         so that invoice_save() will save it to disk.
//
// @return SUCCESS.  (What could go wrong?)
///

dcl-proc invoice_setHeader export;

  dcl-pi *n int(10);
    header  likeds(INVOICE_header_t);
  end-pi;

  dcl-s curDate date(*iso) inz(*sys);

  Initialize();

  eval-corr gINV.hdr = header;
  if gINV.hdr.crtdate = 0;
    gINV.hdr.crtdate = %dec( curDate: *iso );
  endif;
  if gINV.hdr.invdate = 0;
    gINV.hdr.invdate = %dec( curDate: *iso );
  endif;
  gINV.count = 0;

  return SUCCESS;
end-proc;


///
//  invoice_checkItem():
//    Validate an item number, and optionally return
//    some of the default attributes of that item.
//
// @param (input) item number to validate.
//
// @param (output/opt) description of item if valid
// @param (output/opt) default unit of measure if valid
// @param (output/opt) default price of item if valid
//
// @return SUCCESS or FAIL
///
dcl-proc invoice_checkItem export;

  dcl-pi *n int(10);
    itemno   like(ITEMMAS_t.itemno) const;
    dftDescr like(ITEMMAS_t.descr)  options(*omit:*nopass);
    dftUom   like(ITEMMAS_t.uom)    options(*omit:*nopass);
    dftPrice like(ITEMMAS_t.price)  options(*omit:*nopass);
  end-pi;

  dcl-s descr like(ITEMMAS_t.descr);
  dcl-s price like(ITEMMAS_t.price);
  dcl-s uom   like(ITEMMAS_t.uom);

  dcl-ds INV1012 qualified;
    itemno packed(5: 0);
  end-ds;
  dcl-ds INV1013 qualified;
    itemno packed(5: 0);
    state  char(5);
  end-ds;

  Initialize();

  exec SQL
    select descr, uom, price
      into :descr, :uom, :price
      from ITEMMAS
      where ITEMNO = :itemno;

  if %subst(sqlstt:1:2) = '02';
    INV1012.itemno = itemno;
    setError('INV1012': INV1012: %size(INV1012));
    return FAIL;
  endif;

  if %subst(sqlstt:1:2)<>'00' and %subst(sqlstt:1:2)<>'01';
    INV1013.itemno = itemno;
    INV1013.state  = sqlstt;
    setError('INV1013': INV1013: %size(INV1013));
    return FAIL;
  endif;

  if %parms >= 2 and %addr(dftDescr)<>*null;
    dftDescr = descr;
  endif;
  if %parms >= 3 and %addr(dftUom)<>*null;
    dftUom = uom;
  endif;
  if %parms >=4 and %addr(dftPrice)<>*null;
    dftPrice = price;
  endif;

  return SUCCESS;
end-proc;


///
// invoice_checkPrice()
//   Check if a price is valid for a given item
//
// @param (input) item number to validate price for
// @param (input) price to check
//
// @return SUCCESS or FAIL
///

dcl-proc invoice_checkPrice export;

  dcl-pi *n int(10);
    itemno   like(ITEMMAS_t.itemno) const;
    price    like(INVDET_t.price) const;
  end-pi;

  dcl-s winner char(1) inz('N');

  dcl-ds INV1014 qualified;
    itemno packed(5: 0);
    price  packed(9: 3);
  end-ds;
  dcl-ds INV1015 qualified;
    itemno packed(5: 0);
    price  packed(9: 3);
    state  char(5);
  end-ds;

  exec SQL
        select 'Y'
          into :winner
          from ITEMMAS i
         where i.ITEMNO = :itemno
           and :price between i.MINPRC and i.MAXPRC;

  if winner = 'Y';
    return SUCCESS;
  elseif %subst(sqlstt:1:2) = '02';
    INV1014.itemno = itemno;
    INV1014.price  = price;
    setError('INV1014': INV1014: %size(INV1014));
    return FAIL;
  else;
    INV1015.itemno = itemno;
    INV1015.price  = price;
    INV1015.state = sqlstt;
    setError('INV1015': INV1015: %size(INV1015));
    return FAIL;
  endif;

end-proc;


///
//  invoice_setDetail()
//    Sets a line item on the loaded invoice
//
// @param (input) detail information to set
//
//  @info If the line number is set within the defail structure, it
//        will replace an existing line item on the invoice with that
//        number.  IF the line number is 0, it is added to the end of
//        the invoice.
//
// @return SUCCESS or FAIL
///

dcl-proc invoice_setDetail export;

  dcl-pi *n int(10);
    detail  likeds(INVOICE_detail_t);
  end-pi;

  dcl-s line   like(INVDET_t.LINENO);
  dcl-s itemno like(INVDET_t.itemno);
  dcl-s wgtlbs like(ITEMMAS_t.wgtlbs);

  dcl-ds INV1016 qualified;
    line int(10);
    elem int(10);
  end-ds;

  line = detail.lineno;
  if line = 0;
    line = gINV.count + 1;
    if line > %elem(gINV.det);
      INV1016.line = line;
      INV1016.elem = %elem(gINV.det);
      setError('INV1016': INV1016: %size(INV1016));
      return FAIL;
    endif;
    detail.lineno = line;
  endif;

  detail.invno = gINV.hdr.invno;

  if detail.wgtlbs = 0;
    wgtlbs = 0;
    itemno = detail.itemno;
    exec SQL
      select wgtlbs
        into :wgtlbs
        from itemmas where itemno=:itemno;
    detail.wgtlbs = wgtlbs;
  endif;

  eval-corr gINV.det(line) = detail;

  if line > gINV.count;
    gINV.count = line;
  endif;

  return SUCCESS;
end-proc;


///
// invoice_save()
//   Save invoice currently in memory to disk
//
//  @info Also updates the customer's last ordered date if needed.
//
//  @info The invoice should be previously set via the setHeader and
//  setDetail routines. (Or getHeader, readList)
//
// @return SUCCESS or FAIL
///

dcl-proc invoice_save export;

  dcl-pi *n int(10);
  end-pi;

  dcl-s invno    like(INVHDR_t.invno);
  dcl-s custno   like(INVHDR_t.custno);
  dcl-s crtdate8 like(INVHDR_t.crtdate);
  dcl-s count    int(10);
  dcl-ds hdr     likeds(INVHDR_t);
  dcl-ds det     likeds(INVDET_t) dim(999);
  dcl-s  i       int(10);
  dcl-s  subtotal like(INVHDR_t.subtotal);
  dcl-s  weight   like(INVHDR_t.weight);

  dcl-ds INV1006 qualified;
    state char(5);
  end-ds;

  dcl-ds INV1007 qualified;
    invno   packed(7: 0);
    crtdate packed(8: 0);
    count   int(10);
    state   char(5);
  end-ds;

  dcl-ds INV1008 qualified;
    invno   packed(7: 0);
    crtdate packed(8: 0);
    state   char(5);
  end-ds;

  if gINV.hdr.invno = 0 or gINV.count = 0;
    setError('INV1005': ' ': 0);
    return FAIL;
  endif;

  count    = gINV.count;
  crtdate8 = gINV.hdr.crtdate;
  invno    = gINV.hdr.invno;
  custno   = gINV.hdr.custno;
  eval-corr hdr = gINV.hdr;

  subtotal = 0;
  weight   = 0;

  for i = 1 to gINV.count;
    eval-corr det(i) = gINV.det(i);
    det(i).crtdate = crtdate8;
    monitor;
      subtotal += %dech( det(i).qty * det(i).price: 9: 3);
      weight   += %dech( det(i).qty * det(i).wgtlbs: 9: 1);
    on-error;
      subtotal = *hival;
      weight   = *hival;
    endmon;
  endfor;

  monitor;
    hdr.subtotal = subtotal;
    hdr.weight = weight;
    hdr.total = hdr.subtotal + hdr.shipping + hdr.tax;
  on-error;
    hdr.total = *hival;
  endmon;

  exec SQL delete
      from INVDET
     where INVNO = :invno and CRTDATE = :crtdate8;

  if %subst(sqlstt:1:2) <> '00'
    and %subst(sqlstt:1:2) <> '01'
    and %subst(sqlstt:1:2) <> '02';
    INV1006.state = SQLSTT;
    setError('INV1006':INV1006:%size(INV1006));
    return FAIL;
  endif;

  exec SQL insert into INVDET
            :count rows values(:det);
  if %subst(sqlstt:1:2) <> '00'
    and %subst(sqlstt:1:2) <> '01';
    INV1007.invno   = invno;
    INV1007.crtdate = crtdate8;
    INV1007.count   = count;
    INV1007.state   = SQLSTT;
    setError('INV1007':INV1007:%size(INV1007));
    return FAIL;
  endif;

  exec SQL
    update INVHDR set ROW = (:hdr)
     where invno = :invno and crtdate = :crtdate8;

  if sqlstt = '02000';
    exec SQL
      insert into INVHDR values(:hdr);
  endif;

  if %subst(sqlstt:1:2)<>'00' and %subst(sqlstt:1:2)<>'01';
    INV1008.invno   = invno;
    INV1008.crtdate = crtdate8;
    INV1008.state   = SQLSTT;
    setError('INV1008':INV1008:%size(INV1008));
    return FAIL;
  endif;

  exec SQL
     update CUSTMAS
        set LASTORD = :crtdate8
      where CUSTNO = :custno
        and LASTORD < :crtdate8;

  return SUCCESS;
end-proc;


///
//  invoice_markPaid():
//    Marks an invoice paid and updates a customer's
//      last paid date.
//
// @param (input) invoice number to mark paid
// @param (input/opt) create date of the invoice to mark paid.
//                        if not provided, the newest invoice that
//                        bears the invoice number will be paid.
//
// @return SUCCESS or FAIL
///

dcl-proc invoice_markPaid export;

  dcl-pi *n int(10);
    invno   like(INVHDR_t.invno) const;
    crtdate date(*iso)   const options(*omit:*nopass);
  end-pi;

  dcl-s crtdate8 like(INVHDR_t.crtdate) inz(0);
  dcl-s curdate  like(CUSTMAS_t.LASTPAID);

  dcl-ds INV1009 qualified;
    invno   packed(7: 0);
    crtdate packed(8: 0);
    state   char(5);
  end-ds;

  dcl-ds INV1010 qualified;
    invno   packed(7: 0);
    crtdate packed(8: 0);
    curdate packed(8: 0);
    state   char(5);
  end-ds;

  if %parms >= 2 and %addr(crtdate)<>*null;
    crtdate8 = %dec(crtdate:*iso);
  endif;

  exec SQL
    update INVHDR h
        set h.PAIDDATE = dec(varchar_format (CURRENT DATE, 'YYYYMMDD'), 8)
      where h.INVNO = :invno
        and (:crtdate8 = 0 or h.CRTDATE = :crtdate8);

  if %subst(sqlstt:1:2)<>'00' and %subst(sqlstt:1:2)<>'01';
    INV1009.invno   = invno;
    INV1009.crtdate = crtdate8;
    INV1009.state   = sqlstt;
    setError('INV1009':INV1009:%size(INV1009));
    return FAIL;
  endif;

  curdate = %dec(%date():*iso);

  exec SQL
     update CUSTMAS c
        set c.LASTPAID = :curdate
      where c.CUSTNO =
        (select CUSTNO
           from INVHDR h
          where h.INVNO = :invno
            and (:crtdate8 = 0 or h.CRTDATE = :crtdate8))
        and c.LASTPAID < :curdate;

  if %subst(sqlstt:1:2)<>'00' and %subst(sqlstt:1:2)<>'01';
    INV1010.invno   = invno;
    INV1010.crtdate = crtdate8;
    INV1010.curdate = curdate;
    INV1010.state   = sqlstt;
    setError('INV1010':INV1010:%size(INV1010));
    return FAIL;
  endif;

  return SUCCESS;
end-proc;


///
//  invoice_delete()
//     Deletes an invoice from disk.
//
// @param (input) invoice number to delete
// @param (input/opt) create date of invoice to delete. If not
//             provided, the newest invoice with the invoice number
//             is deleted.
//
// @return SUCCESS or FAIL
///

dcl-proc invoice_delete export;

  dcl-pi *n int(10);
    invno   like(INVHDR_t.invno) const;
    crtdate date(*iso)   const options(*omit:*nopass);
  end-pi;

  dcl-s crtdate8 like(INVHDR_t.crtdate) inz(0);
  dcl-s rc int(10) inz(SUCCESS);

  dcl-ds INV1011 qualified;
    invno   packed(7: 0);
    crtdate packed(8: 0);
    state   char(5);
  end-ds;

  if %parms >= 2 and %addr(crtdate)<>*null;
    crtdate8 = %dec(crtdate:*iso);
  endif;

  exec SQL
    delete from INVDET d
      where d.INVNO = :invno
        and (:crtdate8 = 0 or d.CRTDATE = :crtdate8);

  if %subst(sqlstt:1:2)<>'00' and %subst(sqlstt:1:2)<>'01'
    and %subst(sqlstt:1:2)<>'02';
    INV1011.invno   = invno;
    INV1011.crtdate = crtdate8;
    INV1011.state   = sqlstt;
    setError('INV1011':INV1011:%size(INV1011));
    rc = FAIL;
  endif;

  exec SQL
    delete from INVHDR h
      where h.INVNO = :invno
        and (:crtdate8 = 0 or h.CRTDATE = :crtdate8);
  if %subst(sqlstt:1:2)<>'00' and %subst(sqlstt:1:2)<>'01';
    INV1011.invno   = invno;
    INV1011.crtdate = crtdate8;
    INV1011.state   = sqlstt;
    setError('INV1011':INV1011:%size(INV1011));
    rc = FAIL;
  endif;

  return rc;
end-proc;

///
// fmtcsz
//   INTERNAL: Formats the CSZ (city/state/zip) line of the address
//   given the 3 separate fields.
//
// @param (input) city
// @param (input) US state or canadian province code (blank=none)
// @param (input) postal code (zip code in the usa)
//
// @return the formatted city/state/zip line of an address
///

dcl-proc fmtcsz;

  dcl-pi *n char(35);
    city   like(INVHDR_t.DELCITY)   const;
    state  like(INVHDR_t.DELSTATE)  const;
    postal like(INVHDR_t.DELPOSTAL) const;
  end-pi;

  dcl-s csz char(35);

  csz = city;
  if state <> ' ';
    csz = %trimr(csz) + ', ' + state;
  endif;
  if postal < ' ';
    csz = %trimr(csz) + ' ' + postal;
  endif;

  return csz;
end-proc;


///
// invoice_print()
//    Print an invoice to a printer or PDF file
//
// @param (input) invoice number to print
// crtdate - (input/opt) create date of invoice to print. if not
//             provided, the newest invoice with the invoice number
//             will be selected.
// @param (input/opt) output queue to print invoice to
//             if not provided, the invoice is not printed.
// @param (input/opt) IFS stream file to write a PDF copy of
//             the invoice to.  If not provided, it will not be
//             written to disk.
//
// @return SUCCESS or FAIL
///

dcl-proc invoice_print export;

  dcl-pi *n int(10);
    invno   like(INVHDR_t.invno) const;
    crtdate date(*iso)    const options(*omit:*nopass);
    outq    varchar(21)   const options(*omit:*nopass);
    stmf    varchar(5000) const options(*omit:*nopass);
  end-pi;

  dcl-f INVOICEP printer extdesc('INVOICE')
                         extfile(*extdesc)
                         oflind(overflow) usropn;

  dcl-s crtdate8 like(INVHDR_t.crtdate) inz(0);
  dcl-s overflow ind;
  dcl-s cmd      varchar(2000);
  dcl-s rc       int(10) inz(SUCCESS);
  dcl-s i        int(10) inz(0);
  dcl-s first    ind inz(*on);
  dcl-s termsMsg varchar(18);
  dcl-s overlay  varchar(21);

  dcl-ds H  likerec(HEADING: *output);
  dcl-ds D1 likerec(DETAIL1: *output);
  dcl-ds D2 likerec(DETAIL2: *output);
  dcl-ds F  likerec(FOOTER:  *output);

  if %parms >= 2 and %addr(crtdate)<>*null;
    rc = invoice_getHeader(invno: crtdate);
  else;
    rc = invoice_getHeader(invno);
  endif;
  if rc = FAIL;
    return FAIL;
  endif;

  if PSDS.library = 'ORCINV';
    overlay = '*LIBL/ORCINV';
  else;
    overlay = '*LIBL/INVOICE';
  endif;

  if %parms >= 4 and %addr(stmf)<>*null;
    cmd = 'OVRPRTF FILE(INVOICE) +
                   TOSTMF(''' + stmf + ''') +
                   WSCST(*PDF) +
                   PAGESIZE(66 85 *ROWCOL) +
                   OVRFLW(41) +
                   FRONTOVL(' + overlay + ' 0.07 0) +
                   DEVTYPE(*AFPDS)';
  elseif %parms >= 3 and %addr(outq)<>*null;
    cmd = 'OVRPRTF FILE(INVOICE) +
                   OUTQ(' + outq + ') +
                   PAGESIZE(66 85 *ROWCOL) +
                   OVRFLW(41) +
                   FRONTOVL(' + overlay + ' 0.07 0) +
                   DEVTYPE(*AFPDS)';
  else;
    return FAIL;
  endif;

  QCMDEXC(cmd:%len(cmd));
  open INVOICEP;

  eval-corr H = gINV.hdr;
  eval-corr F = gINV.hdr;

  select;
  when gINV.hdr.invdate = 0 or gINV.hdr.invdate = 00010101;
    H.invdateus = *loval;
  when gINV.hdr.invdate = 99999999 or gINV.hdr.invdate = 99991231;
    H.invdateus = *hival;
  other;
    H.invdateus = %date(gINV.hdr.invdate:*iso);
  endsl;

  H.delcsz    = fmtcsz( gINV.hdr.delCity
                      : gINV.hdr.delState
                      : gINV.hdr.delPostal );
  H.bilcsz    = fmtcsz( gINV.hdr.bilCity
                      : gINV.hdr.bilState
                      : gINV.hdr.bilPostal );

  if H.delcntry = 'USA';
    H.delcntry = *blanks;
  endif;
  if H.bilcntry = 'USA';
    H.bilcntry = *blanks;
  endif;

  invoice_getTermsMsg( gINV.hdr.termType
                     : gINV.hdr.termDays
                     : termsMsg );
  H.termsMsg = '      ' + termsMsg;

  write HEADING H;

  for i = 1 to gINV.count;

    eval-corr D2 = gINV.det(i);

    monitor;
      D2.lineamt = %dech(D2.qty * D2.price : 9 : 3);
    on-error;
      D2.lineamt = *hival;
    endmon;

    if overflow;
      write FOOTER F;
      write HEADING H;
      first = *on;
      overflow = *off;
    endif;

    if first = *on;
      eval-corr D1 = D2;
      first = *off;
      write DETAIL1 D1;
    else;
      write DETAIL2 D2;
    endif;

  endfor;

  write FOOTER F;

  close INVOICEP;

  cmd = 'DLTOVR FILE(INVOICE)';
  QCMDEXC(cmd:%len(cmd));

  return SUCCESS;
end-proc;


///
// invoice_toJobDate()
//   Converts a date in ISO (YYYYMMDD) format to
//   the current 6-digit date format of the job
//
// @param (input) the date in ISO format to convert
//
// @return the date in job format.
///

dcl-proc invoice_toJobDate export;

  dcl-pi *n packed(6: 0);
    isoDate packed(8: 0) const;
  end-pi;

  dcl-s jobDate packed(8: 0);

  select;
  when isoDate = 0 or isoDate = 00010101;
    jobDate = 0;
  when isoDate = *hival or isoDate = 99991231;
    jobDate = 999999;
  other;
    jobDate = %dec(%date(isoDate:*iso): *jobrun);
  endsl;

  return jobDate;
end-proc;


///
// invoice_toIsoDate()
//   Converts a date from job format to ISO
//
// @param (input) date in the current job 6-digit date format.
//
// @return the date in ISO (YYYYMMDD) format.
///

dcl-proc invoice_toIsoDate export;

  dcl-pi *n packed(8: 0);
    jobDate packed(6: 0) const;
  end-pi;

  dcl-s isoDate packed(8: 0);

  select;
  when jobDate = 0;
    isoDate = 0;
  when jobDate = *hival;
    isoDate = *hival;
  other;
    isoDate = %dec(%date(jobDate:*jobrun): *iso);
  endsl;

  return isoDate;
end-proc;


///
// invoice_checkUOM
//   Validates the unit of measure provided by a
//   user and optionally retrieves a descriptive UOM
//
// @param (input) unit of measure to validate.
// @param (output/opt) 3 character descriptive unit of measure
// @param (output/opt) 12 character descriptive unit of measure
//
// @return SUCCESS or FAIL
///

dcl-proc invoice_checkUom export;

  dcl-pi *n int(10);
    uom   like(UNITS_t.code)  const;
    uom3  like(UNITS_t.Code3) options(*omit:*nopass);
    uom12 like(UNITS_t.Desc)  options(*omit:*nopass);
  end-pi;

  dcl-s Code3 char(3);
  dcl-s Desc  char(12);

  dcl-ds INV1017 qualified;
    uom like(UNITS_t.code);
  end-ds;
  dcl-ds INV1018 qualified;
    uom like(UNITS_t.code);
    state char(5);
  end-ds;

  exec SQL
    select UNCODE3, UNDESC
      into :Code3, :Desc
      from UNITS
     where UNCODE = :uom;

  if %subst(sqlstt:1:2) = '02';
    INV1017.uom = uom;
    setError('INV1017': INV1017: %size(INV1017));
    return FAIL;
  endif;

  if %subst(sqlstt:1:2)<>'00' and %subst(sqlstt:1:2)<>'01';
    INV1018.uom = uom;
    INV1018.state = sqlstt;
    setError('INV1018': INV1018: %size(INV1018));
    return FAIL;
  endif;

  if %parms >= 2 and %addr(uom3)<>*null;
    uom3 = Code3;
  endif;

  if %parms >= 3 and %addr(uom12)<>*null;
    uom12 = Desc;
  endif;

  return SUCCESS;
end-proc;


///
// invoice_getTermsMsg
//    Returns a descriptive message for a terms code and days.
//
// @param (input) terms code
// @param (input) days allowed under this terms code
// @param (output) the descriptive message
//
// @return FAIL if terms code is invalid, otherwise SUCCESS
///
dcl-proc invoice_getTermsMsg export;

  dcl-pi *n int(10);
    terms    like(CUSTMAS_t.termType) const;
    days     like(CUSTMAS_t.termDays) const;
    termsMsg varchar(18);
  end-pi;

  dcl-ds INV1019 qualified;
    terms like(CUSTMAS_t.termType);
  end-ds;

  Select;
  when terms = 'N';
    termsMsg = 'Net/' + %char(days);
  when terms = 'M';
    termsMsg = 'Net EOM/' + %char(days);
  other;
    INV1019.terms = terms;
    setError('INV1019': INV1019: %size(INV1019));
    return FAIL;
  endsl;

  return SUCCESS;
end-proc;


///
// setError()
//  INTERNAL: sets the last error message for this module
//
//  @param (input) message id to set INVxxxx
//  @param (input) fill-in message data (variable-length)
//  @param (input) length of 'msgdta'
///
dcl-proc setError;

  dcl-pi *n;
    msgid     char(7)     const;
    msgdta    char(32768) const options(*varsize);
    msgdtalen int(10)     value;
  end-pi;

  gERR.msgid     = msgid;
  gERR.msgdta    = msgdta;
  gERR.msgdtalen = msgdtalen;

  return;
end-proc;


///
// invoice_getLastErr():
//   Retrieve the last error message that occurred within
//   the invoice service program.
//
// @param (output/opt) message id of the error
// @param (output/opt) fill-in data for this message
// @param (output/opt) length of fill-in data
//
// @return a human-readable message of the last error that occurred
//         or '' if there has been no errors since the module was
//         initialized.
///
dcl-proc invoice_getLastErr export;

  dcl-pi *n varchar(32767);
    msgId     char(7)     options(*nopass:*omit);
    msgDta    char(32767) options(*nopass:*omit);
    msgDtaLen int(10)     options(*nopass:*omit);
  end-pi;

  dcl-pr QMHRTVM extpgm;
    rcvvar    char(32767) options(*varsize);
    rcvvarlen int(10)     const;
    format    char(8)     const;
    msgId     char(7)     const;
    qualMsgf  char(20)    const;
    msgDta    char(32767) const options(*varsize);
    msgDtaLen int(10)     const;
    replace   char(10)    const;
    rtnctrl   char(10)    const;
    errCode   char(32767) options(*varsize);
  end-pr;

  dcl-ds rcvvar qualified;
    bytesReturned int(10);
    bytesAvail    int(10);
    sev           int(10);
    alertIdx      int(10);
    alertOpt      char(9);
    logInd        char(1);
    *n            char(2);
    lenRpy        int(10);
    lenRpyAvail   int(10);
    lenMsg        int(10);
    lenMsgAvail   int(10);
    lenHlp        int(10);
    lenHlpAvail   int(10);
    buffer        char(65535);
  end-ds;

  dcl-ds errCode qualified;
    bytesProvided  int(10) inz(0);
    bytesAvail     int(10) inz(0);
  end-ds;

  dcl-s msg    char(32767) based(p_msg);
  dcl-s len    int(10);
  dcl-s rtnMsg varchar(32767);

  if %parms >= 1 and %addr(msgId)<>*null;
    msgId = gERR.msgId;
  endif;

  if %parms >= 2 and %addr(msgDta)<>*null;
    msgDta = gERR.msgDta;
  endif;

  if %parms >= 3 and %addr(msgDtaLen)<>*null;
    msgDtaLen = gERR.msgDtaLen;
  endif;

  rtnMsg = '';

  if gERR.msgId <> *blanks;
    QMHRTVM( rcvvar
            : %size(rcvvar)
            : 'RTVM0200'
            : gERR.msgId
            : 'INVMSGF   *LIBL'
            : gERR.msgDta
            : gERR.msgDtaLen
            : '*YES'
            : '*NO'
            : errCode );

    p_msg = %addr(rcvvar.buffer) + rcvvar.lenRpy;
    len = rcvvar.lenMsg;

    if len > %size(msg);
      len = %size(msg);
    endif;

    if len >= 1;
      rtnMsg = %subst(msg:1:len);
    endif;
  endif;

  return rtnMsg;
end-proc;
