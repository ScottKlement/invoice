**free

/if defined(*CRTBNDRPG)
ctl-opt dftactgrp(*no) actgrp('SKC');
/endif
ctl-opt option(*srcstmt:*nodebugio) bnddir('INVOICE');
ctl-opt main(MAINLINE);

dcl-f INVENTD workstn sfile(INVENT1S:RRN1)
                      sfile(INVENT4S:RRN4)
                      indds(dspIndMap);

/copy INVOICE_H

dcl-c GO_BACK -1;
dcl-c CONTINUE 0;
dcl-c QUIT     1;
dcl-c SAVE     2;

dcl-ds dspIndMap;
  EXIT       ind pos(3);
  PROMPT     ind pos(4);
  REFRESH    ind pos(5);
  CREATE     ind pos(6);
  CANCEL     ind pos(12);
  PRINT      ind pos(25);
  SFLCLR1    ind pos(50);
  SFLDSP1    ind pos(51);
  SFLCLR4    ind pos(60);
  SFLDSP4    ind pos(61);
  CHANGES4   ind pos(62);
end-ds;

dcl-s RRN1     packed(4: 0);
dcl-s RRN4     packed(4: 0);
dcl-s HIGHRRN1 like(RRN1);
dcl-s HIGHRRN4 like(RRN4);

//-------------------------------------------------------------------
//  Mainline: This is the main control flow of the program
//-------------------------------------------------------------------

dcl-proc MAINLINE;

  dcl-s step int(10) inz(1);
  dcl-s rc   int(10);

  if not %open(INVENTD);
    open INVENTD;
  endif;

  dou rc = QUIT;

    select;
    when step = 1;
      rc = LoadOrderList();
    when step = 2;
      rc = SelectOrder();
    endsl;

    if rc = GO_BACK;
      step -= 1;
    else;
      step += 1;
    endif;

  enddo;

  return;

on-exit;

  close *all;

end-proc;


//-------------------------------------------------------------------
// LoadOrderList(): Loads a list of previous orders for the
//                  user to choose to edit.
//
// returns CONTINUE when list is loaded.
//-------------------------------------------------------------------

dcl-proc LoadOrderList;

  dcl-pi *n int(10);
  end-pi;

  dcl-ds INV likeds(INVOICE_HEADER_t) inz;
  dcl-ds dsp1s likerec(INVENT1S:*ALL) inz;

  SFLDSP1 = *OFF;
  SFLCLR1 = *ON;
  write INVENT1C;
  SFLCLR1 = *OFF;
  RRN1 = 0;
  HIGHRRN1 = 0;

  invoice_openList(*off);

  dow invoice_readList(INV) = SUCCESS;
    eval-corr dsp1s = INV;
    dsp1s.crtdate6 = invoice_toJobDate(INV.crtdate);
    RRN1 += 1;
    sfldsp1 = *on;
    write INVENT1S dsp1s;
  enddo;

  invoice_closeList();
  HIGHRRN1 = RRN1;
  return CONTINUE;

end-proc;


//-------------------------------------------------------------------
// SelectOrder(): Displays a screen where the user can select an
//                invoice to change, or press F6=Create New.
//
// returns QUIT if user wishes to leave program.
//      or GO_BACK if the list of orders should be reloaded
//-------------------------------------------------------------------

dcl-proc SelectOrder;

  dcl-pi *n int(10);
  end-pi;

  dcl-ds DSP1F likerec(INVENT1F:*ALL) inz;
  dcl-ds DSP1S likerec(INVENT1S:*ALL) inz;
  dcl-ds DSP1C likerec(INVENT1C:*ALL) inz;
  dcl-s  rc    int(10);
  dcl-s  need_refresh ind inz(*off);

  dou EXIT or CANCEL;

    if DSP1C.LASTRRN1 < 1 or DSP1C.LASTRRN1 > HIGHRRN1;
      DSP1C.NEXTRRN1 = 1;
    else;
      DSP1C.NEXTRRN1 = DSP1C.LASTRRN1;
    endif;

    write INVENT1F DSP1F;
    exfmt INVENT1C DSP1C;
    DSP1F.MSG = *BLANKS;

    select;
    when EXIT or CANCEL;
      return QUIT;
    when REFRESH;
      return GO_BACK;
    when CREATE;
      if CreateNewOrder(DSP1F.MSG) <> QUIT;
        return GO_BACK;
      endif;
    endsl;

    need_refresh = *off;

    for RRN1 = 1 to HIGHRRN1;

      chain RRN1 INVENT1S DSP1S;
      rc = CONTINUE;

      select;
      when DSP1S.OPT = '2';
        rc = ChangeOrder(DSP1S: DSP1F.MSG);
        need_refresh = *on;
      when DSP1S.OPT = '4';
        rc = DeleteOrder(DSP1S);
        need_refresh = *on;
      when DSP1S.OPT = '9';
        rc = MarkOrderPaid(DSP1S);
        need_refresh = *on;
      endsl;

      if rc = QUIT;
        return QUIT;
      endif;

      DSP1S.OPT = ' ';
      update INVENT1S DSP1S;

    endfor;

    if need_refresh;
      leave;
    endif;

  enddo;

  return GO_BACK;

end-proc;


//-------------------------------------------------------------------
// CreateNewOrder(): Displays a screen where the user can type a
//                   customer to create a new order for, then
//                   creates an order.
//
//   ERR = (output) error message to report to prior screen
//
//  Returns GO_BACK to indicate that the new order was cancelled
//      or CONTINUE to indicate that it was created
//-------------------------------------------------------------------

dcl-proc CreateNewOrder;

  dcl-pi *n int(10);
    ERR like(MSG);
  end-pi;


  dcl-ds INV likeds(INVOICE_header_t);
  dcl-ds DSP2 likerec(INVENT2:*ALL) inz;

  DOU DSP2.MSG = *BLANKS;

    exfmt INVENT2 DSP2;
    DSP2.MSG = *BLANKS;

    IF EXIT or CANCEL;
      return GO_BACK;
    endif;

    if INVOICE_create(DSP2.CUSTNO: INV) = FAIL;
      DSP2.MSG = INVOICE_getLastErr();
    endif;

  ENDDO;

  return EditOrder(INV: ERR);
end-proc;


//-------------------------------------------------------------------
// ChangeOrder(): Allows changes to an existing order
//
//   INP = (input) Order selected to be changed
//   ERR = (output) error message to report to prior screen
//
//  Returns GO_BACK to indicate that editing was cancelled
//      or CONTINUE to indicate that it was saved to disk
//-------------------------------------------------------------------

dcl-proc ChangeOrder;

  dcl-pi *n int(10);
    inp likerec(INVENT1S:*ALL) const;
    err like(msg);
  end-pi;

  dcl-ds INV likeds(INVOICE_header_t);

  err = *blanks;
  if invoice_getHeader( inp.INVNO
                      : %date(inp.CRTDATE6: *JOBRUN)
                      : INV) = FAIL;
    err = INVOICE_getLastErr();
    return CONTINUE;
  endif;

  return EditOrder(INV: err);
end-proc;


//-------------------------------------------------------------------
// DeleteOrder(): Deletes an order
//
//   INP = (input) Order selected to be deleted
//
//  Returns QUIT to indicate that delete was cancelled
//      or CONTINUE to indicate that it was deleted
//-------------------------------------------------------------------

dcl-proc DeleteOrder;

  dcl-pi *n int(10);
    inp likerec(INVENT1S:*ALL) const;
  end-pi;

  dcl-ds DSP5 likerec(INVENT5:*ALL);

  DSP5.SAVEINVNO  = inp.INVNO;
  DSP5.SAVECRTDT6 = inp.CRTDATE6;
  DSP5.SAVECUST   = inp.CUSTNO;
  DSP5.SAVEAMT    = inp.TOTAL;
  DSP5.CONFIRM    = 'N';

  dou DSP5.MSG = *BLANKS;

    exfmt INVENT5 DSP5;
    DSP5.MSG = *BLANKS;

    if EXIT or CANCEL;
      return QUIT;
    endif;

    if DSP5.CONFIRM <> 'Y' and DSP5.CONFIRM <> 'N';
      DSP5.MSG = 'You must say Y (=Yes) or N (=No)';
      iter;
    endif;

    if DSP5.MSG=*BLANKS and DSP5.CONFIRM='Y';
      if invoice_delete( DSP5.SAVEINVNO
                       : %date(DSP5.SAVECRTDT6: *jobrun)
                       ) = FAIL;
        DSP5.MSG = invoice_getLastErr();
      endif;
    endif;

  enddo;

  return CONTINUE;
end-proc;


//-------------------------------------------------------------------
// MarkOrderPaid(): Marks an invoice paid
//
//   INP = (input) Order selected to be marked
//
//  Returns QUIT to indicate that paying was cancelled
//      or CONTINUE to indicate that it was paid
//-------------------------------------------------------------------

dcl-proc MarkOrderPaid;

  dcl-pi *n int(10);
    inp likerec(INVENT1S:*ALL) const;
  end-pi;

  dcl-ds DSP6 likerec(INVENT6:*ALL);

  DSP6.SAVEINVNO  = inp.INVNO;
  DSP6.SAVECRTDT6 = inp.CRTDATE6;
  DSP6.SAVECUST   = inp.CUSTNO;
  DSP6.SAVEAMT    = inp.TOTAL;
  DSP6.CONFIRM    = 'N';

  dou DSP6.MSG = *BLANKS;

    exfmt INVENT6 DSP6;
    DSP6.MSG = *BLANKS;

    if EXIT or CANCEL;
      return QUIT;
    endif;

    if DSP6.CONFIRM <> 'Y' and DSP6.CONFIRM <> 'N';
      DSP6.MSG = 'You must say Y (=Yes) or N (=No)';
      iter;
    endif;

    if DSP6.MSG=*BLANKS and DSP6.CONFIRM='Y';
      if invoice_markPaid( DSP6.SAVEINVNO
                         : %date(DSP6.SAVECRTDT6: *jobrun)
                         ) = FAIL;
        DSP6.MSG = invoice_getLastErr();
      endif;
    endif;

  enddo;

  return CONTINUE;
end-proc;


//-------------------------------------------------------------------
// EditOrder(): Edits the currently loaded invoice
//
//   INV = (input) Loaded invoice to edit
//   ERR = (output) error message to report to prior screen
//
//  Returns GO_BACK to indicate that editing was cancelled
//      or CONTINUE to indicate that it was saved to disk
//-------------------------------------------------------------------

dcl-proc EditOrder;

  dcl-pi *n int(10);
    INV likeds(INVOICE_HEADER_t);
    ERR like(MSG);
  end-pi;

  dcl-ds DSP3  likerec(INVENT3:  *ALL) inz;
  dcl-ds DSP4C likerec(INVENT4C: *ALL) inz;
  dcl-ds DSP4S likerec(INVENT4S: *ALL) inz;
  dcl-ds DSP4F likerec(INVENT4F: *ALL) inz;
  dcl-ds DSP7  likerec(INVENT7:  *ALL) inz;

  dcl-s  count int(10);
  dcl-s  i     int(10);
  dcl-ds det   likeds(INVOICE_detail_t) dim(999) inz;
  dcl-s  rc    int(10);
  dcl-s  step  int(10) inz(1);

  SFLDSP4  = *OFF;
  SFLCLR4  = *ON;
  write INVENT4C;
  SFLCLR4  = *OFF;
  RRN4     = 0;
  HIGHRRN4 = 0;

  eval-corr DSP3  = INV;
  eval-corr DSP4C = INV;
  eval-corr DSP4F = INV;
  eval-corr DSP7  = INV;

  DSP3.DELDATE6    = invoice_toJobDate(INV.DELDATE);
  DSP3.PODATE6     = invoice_toJobDate(INV.PODATE);
  DSP3.LASTORD6    = invoice_toJobDate(INV.LASTORD);
  DSP3.LASTPAID6   = invoice_toJobDate(INV.LASTPAID);
  DSP3.CMACCTREP   = INV.acctrep;
  DSP3.CMTERR      = INV.terr;
  DSP3.CMCHANNEL   = INV.channel;
  DSP3.terms       = INV.termType;
  DSP3.cmTermDays  = INV.termDays;

  count = invoice_getDetail( INV.INVNO
                           : %date(INV.CRTDATE:*iso)
                           : det
                           : %elem(det));
  if count = FAIL;
    ERR = INVOICE_getLastErr();
    return CONTINUE;
  endif;

  DSP4F.totalqty = 0;

  FOR i = 1 to count;
    eval-corr DSP4S = det(i);
    RRN4 += 1;
    sfldsp4 = *on;
    DSP4F.totalqty += DSP4S.qty;
    write INVENT4S DSP4S;
  ENDFOR;

  clear DSP4S;
  FOR i = 1 to 5;
    RRN4 += 1;
    sfldsp4 = *on;
    write INVENT4S DSP4S;
  ENDFOR;

  HIGHRRN4 = RRN4;

  rc = CONTINUE;
  dou rc=SAVE or rc=QUIT;

    select;
    when step = 1;
      rc = EditHeader(DSP3);
    when step = 2;
      rc = EditItems(DSP4C:DSP4F);
    when step = 3;
      rc = EditFooter(DSP7);
    endsl;

    if rc = GO_BACK;
      step -= 1;
    else;
      step += 1;
    endif;

  enddo;

  if rc = SAVE;
    return SaveOrder(DSP3: DSP4C: DSP4F: DSP7);
  else;
    return GO_BACK;
  endif;

end-proc;


//-------------------------------------------------------------------
// EditHeader(): Edits the header information on an invoice
//
//  DSP3 = (i/o) Screen data to edit
//
//  Returns GO_BACK to indicate that editing was cancelled
//      or CONTINUE to indicate that we should proceed
//-------------------------------------------------------------------

dcl-proc EditHeader;

  dcl-pi *n int(10);
    DSP3 likerec(INVENT3:*ALL);
  end-pi;

  dou DSP3.MSG = *BLANKS;

    exfmt INVENT3 DSP3;
    DSP3.MSG = *BLANKS;

    if EXIT or CANCEL;
      return QUIT;
    endif;

  enddo;

  return CONTINUE;
end-proc;


//-------------------------------------------------------------------
// EditItems(): Edits the list of line items on this invoice
//
//  DSP4C = (i/o) Screen data to edit
//  DSP4F = (i/o) Screen data to edit
//
//  Returns GO_BACK to indicate that editing was cancelled
//      or CONTINUE to indicate that we should proceed
//-------------------------------------------------------------------

dcl-proc EditItems;

  dcl-pi *n int(10);
    DSP4C likerec(INVENT4C:*ALL);
    DSP4F likerec(INVENT4F:*ALL);
  end-pi;

  dcl-ds DSP4S       likerec(INVENT4S:*ALL) inz;
  dcl-s  madeChanges ind inz(*off);
  dcl-s  Empty       int(10);
  dcl-s  i           int(10);

  DOU DSP4F.MSG = *BLANKS and madeChanges = *off;

    if DSP4C.LASTRRN4 >= 1 and DSP4C.LASTRRN4 <= HIGHRRN4;
      DSP4C.NEXTRRN4 = DSP4C.LASTRRN4;
    else;
      DSP4C.NEXTRRN4 = 1;
    endif;

    write INVENT4F DSP4F;
    exfmt INVENT4C DSP4C;
    read  INVENT4F DSP4F;

    madeChanges = *off;
    Empty = 0;

    DSP4F.MSG = *BLANKS;
    DSP4F.SUBTOTAL = 0;
    DSP4F.TOTALQTY = 0;

    readc invent4s DSP4S;
    if not %eof or CHANGES4;
      madeChanges = *on;
    endif;

    if EXIT or CANCEL;
      return GO_BACK;
    endif;

    if PROMPT
      and DSP4C.LASTRRN4>=1 and DSP4C.LASTRRN4<=HIGHRRN4;
      chain DSP4C.LASTRRN4 INVENT4S DSP4S;
      LookupItem(DSP4S);
      update INVENT4S DSP4S;
      PROMPT = *OFF;
      madeChanges = *on;
    endif;

    for RRN4 = 1 to HIGHRRN4;

      chain RRN4 INVENT4S DSP4S;

      if DSP4S.itemno=0 and DSP4S.descr=' ' and DSP4S.qty=0 and DSP4S.uom=' '
          and DSP4S.price = 0;
        Empty += 1;
        iter;
      endif;

      select;
      when DSP4S.itemno=0;
        DSP4F.msg = 'Missing item number!';
      when DSP4S.price=0;
        DSP4F.msg = 'Missing price!';
      when DSP4S.qty=0;
        DSP4F.msg = 'Missing quantity!';
      when DSP4S.uom = ' ';
        DSP4F.msg = 'Missing unit of measure!';
      when DSP4S.descr = ' ';
        DSP4F.msg = 'Missing description!';
      endsl;

      if DSP4S.itemno<>0
         and DSP4F.msg = *blanks
         and invoice_checkItem(DSP4S.itemno: descr: uom: price) = FAIL;
        DSP4F.msg = 'Item ' + %char(DSP4S.itemno) + ' not found!';
      endif;

      if DSP4S.price<>0
         and DSP4F.msg = *blanks
         and invoice_checkPrice(DSP4S.itemno: DSP4S.price) = FAIL;
        DSP4F.msg = 'Price ' + %char(DSP4S.price) + ' not allowed +
                     for item ' + %char(DSP4S.itemno) + '!';
      endif;

      if DSP4S.uom<>*blank
         and DSP4F.msg = *blanks
         and invoice_checkUom(DSP4S.uom) = FAIL;
        DSP4F.msg = 'Unit of measure ' + DSP4S.uom + ' not allowed!';
      endif;

      select;
      when DSP4S.price=0;
        DSP4S.price = price;
      when DSP4S.uom = ' ';
        DSP4S.uom = uom;
      when DSP4S.descr = ' ';
        DSP4S.descr = descr;
      endsl;

      monitor;
        DSP4F.subtotal += %dech(DSP4S.qty * DSP4S.price: 9: 2);
      on-error;
        if DSP4F.msg = *blanks;
          DSP4F.msg = 'Error calculating subtotal.';
        endif;
        DSP4F.subtotal = *hival;
      endmon;

      monitor;
        DSP4F.totalqty += DSP4S.qty;
      on-error;
        if DSP4F.msg = *blanks;
          DSP4F.msg = 'Error calculating total qty.';
        endif;
        DSP4F.totalqty = *hival;
      endmon;

      update INVENT4S DSP4S;

    endfor;

    DSP4F.total = DSP4F.subtotal + DSP4F.shipping + DSP4F.tax;

    if Empty < 5;
      clear DSP4S;
      RRN4 = HIGHRRN4;
      for i = Empty to 5;
        RRN4 += 1;
        write INVENT4S DSP4S;
      endfor;
      HIGHRRN4 = RRN4;
      madeChanges = *on;
    endif;

    if DSP4F.msg = *blanks and DSP4F.totalqty = 0;
      DSP4F.msg = 'Enter some items onto this invoice!';
    endif;

  ENDDO;

  return CONTINUE;
end-proc;


//-------------------------------------------------------------------
// EditFooter(): Edits the footer information of an invoice
//
//  DSP7 = (i/o) Screen data to edit
//
//  Returns GO_BACK to indicate that editing was cancelled
//      or SAVE to indicate that we should save the invoice
//-------------------------------------------------------------------

dcl-proc EditFooter;

  dcl-pi *n int(10);
    DSP7  likerec(INVENT7:*ALL);
  end-pi;

  dou DSP7.MSG = *BLANKS;

    exfmt INVENT7 DSP7;
    DSP7.MSG = *BLANKS;

    if CANCEL or EXIT;
      return GO_BACK;
    endif;

  enddo;

  return SAVE;
end-proc;


//-------------------------------------------------------------------
// LookupItem(): Prompt for an item number
//
//  DSP4S = (i/o) Subfile row to contain the prompted item
//
//  Returns QUIT to indicate that prompting was cancelled
//      or CONTINUE to indicate that we should proceed
//-------------------------------------------------------------------

dcl-proc LookupItem;

  dcl-pi *n int(10);
    DSP4S likerec(INVENT4S:*ALL);
  end-pi;

  dcl-s cancelInd ind;
  dcl-s price like(itemmas_t.price);
  dcl-s itemno packed(5: 0);

  dcl-pr ITMINQR extpgm;
    itemno packed(5: 0);
    cancelInd ind;
  end-pr;

  itemno = DSP4S.itemno;

  ITMINQR(itemno: cancelInd);
  if cancelInd = *on;
    return QUIT;
  endif;

  DSP4S.itemno = itemno;
  invoice_checkItem( DSP4S.itemno
                   : DSP4S.DESCR
                   : DSP4S.UOM
                   : price );
  DSP4S.price = price;

  return CONTINUE;
end-proc;


//-------------------------------------------------------------------
// SaveOrder(): Saves an order to disk
//
//  DSP3  = (i/o) Header data to save
//  DSP4C = (i/o) Subfile header data to save
//  DSP4F = (i/o) Line totals to save
//  DSP7  = (i/o) Footer data to save
//
//  Returns GO_BACK to indicate that an error occurred
//      or CONTINUE to indicate that invoie was saved to disk
//-------------------------------------------------------------------

dcl-proc SaveOrder;

  dcl-pi *n int(10);
    DSP3  likerec(INVENT3:  *ALL);
    DSP4C likerec(INVENT4C: *ALL);
    DSP4F likerec(INVENT4F: *ALL);
    DSP7  likerec(INVENT7:  *ALL);
  end-pi;

  dcl-ds hdr likeds(INVOICE_Header_t) inz;
  dcl-ds det likeds(INVOICE_Detail_t) inz;
  dcl-ds dsp4s likerec(invent4s: *all) inz;

  eval-corr hdr = DSP3;
  eval-corr hdr = DSP4C;
  eval-corr hdr = DSP4F;
  eval-corr hdr = DSP7;

  hdr.DELDATE  = invoice_toIsoDate(DSP3.DELDATE6);
  hdr.PODATE   = invoice_toIsoDate(DSP3.PODATE6);
  hdr.LASTORD  = invoice_toIsoDate(DSP3.LASTORD6);
  hdr.LASTPAID = invoice_toIsoDate(DSP3.LASTPAID6);

  invoice_setHeader(hdr);

  for RRN4 = 1 to HIGHRRN4;

    chain RRN4 INVENT4S dsp4s;

    if dsp4s.itemno=0 and dsp4s.descr=' ' and dsp4s.qty=0 and dsp4s.uom=' '
        and dsp4s.price = 0;
      iter;
    endif;

    eval-corr det = dsp4s;
    det.lineno = 0;
    invoice_setDetail(det);

  endfor;

  if invoice_save() = FAIL;
    DSP7.MSG = invoice_getLastErr();
    return GO_BACK;
  endif;

  return CONTINUE;
end-proc;

