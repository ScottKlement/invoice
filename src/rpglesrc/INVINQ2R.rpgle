**FREE

ctl-opt option(*SRCSTMT:*NODEBUGIO) bnddir('INVOICE')  main(MAINLINE);
/if defined(*CRTBNDRPG)
ctl-opt dftactgrp(*no) actgrp('SKC');
/endif

dcl-f INVINQ2D workstn SFILE(INVINQ2S:RRN2)
                       SFILE(INVINQ3S:RRN3)
                       INDDS(dspIndMap)
                       usropn;

dcl-ds PSDS psds qualified;
  library char(10) pos(81);
end-ds;

/copy invoice_h

dcl-c GO_BACK -1;
dcl-c CONTINUE 0;
dcl-c QUIT     1;

dcl-ds dspIndMap;
  EXIT        ind pos(3);
  SWITCH_MODE ind pos(8);
  CANCEL      ind pos(12);
  PRINT       ind pos(25);
  SFLCLR      ind pos(50);
  SFLDSP      ind pos(51);
end-ds;

dcl-s RRN2 packed(4: 0);
dcl-s RRN3 packed(4: 0);
dcl-s HIGHRRN like(RRN2);

dcl-proc MAINLINE;

  dcl-ds DSP1  likerec(INVINQ1:*ALL) inz;
  dcl-ds DSP2C likerec(INVINQ2C:*ALL) inz;
  dcl-ds DSP2F likerec(INVINQ2F:*ALL) inz;
  dcl-ds DSP3C likerec(INVINQ3C:*ALL) inz;
  dcl-ds DSP3F likerec(INVINQ3F:*ALL) inz;

  dcl-s rc   int(10) inz(CONTINUE);
  dcl-s step int(10) inz(1);

  if not %open(INVINQ2D);
    open INVINQ2D;
  endif;

  dou rc = QUIT;

    select;
    when step = 1;
      rc = askInvoice(DSP1);
    when step = 2;
      if rc <> GO_BACK;
        rc = LoadInvoice(DSP1: DSP2C: DSP2F: DSP3C: DSP3F);
      endif;
    when step = 3;
      rc = showInvoice(DSP2C: DSP2F: DSP3C: DSP3F);
    endsl;

    if rc = GO_BACK;
      step -= 1;
    else;
      step += 1;
    endif;

  enddo;

  close INVINQ2D;
  *inlr = *on;
  return;

end-proc;

//=============================================================
// Ask the user for the invoice number to view
//=============================================================
dcl-proc askInvoice;

  dcl-pi *n int(10);
    DSP1 likerec(INVINQ1:*ALL);
  end-pi;

  dou DSP1.MSG = *BLANKS;

    exfmt INVINQ1 DSP1;
    DSP1.MSG = *BLANKS;

    if EXIT or CANCEL;
      return QUIT;
    endif;

    if DSP1.INVNO <= 0;
      DSP1.MSG = 'Please enter an invoice number!';
      iter;
    endif;

  enddo;

  return CONTINUE;
end-proc;


//=============================================================
// Load invoice into memory
//=============================================================

dcl-proc LoadInvoice;

  dcl-pi *n int(10);
    DSP1  likerec(INVINQ1:*ALL);
    DSP2C likerec(INVINQ2C:*ALL);
    DSP2F likerec(INVINQ2F:*ALL);
    DSP3C likerec(INVINQ3C:*ALL);
    DSP3F likerec(INVINQ3F:*ALL);
  end-pi;

  dcl-ds DSP2S likerec(INVINQ2S:*ALL) inz;
  dcl-ds DSP3S likerec(INVINQ3S:*ALL) inz;

  dcl-ds hdr   likeds(invoice_header_t) inz;
  dcl-ds det   likeds(invoice_detail_t) dim(999) inz;
  dcl-s  count int(10);
  dcl-s  i     int(10);

  if invoice_getHeader(DSP1.INVNO: *omit: hdr) = FAIL;
    DSP1.MSG = invoice_getLastErr();
    return GO_BACK;
  endif;

  SFLDSP = *OFF;
  SFLCLR = *ON;
  write INVINQ2C DSP2C;
  write INVINQ3C DSP3C;
  RRN2 = 0;
  RRN3 = 0;
  HIGHRRN = 0;
  SFLCLR = *OFF;

  count = invoice_getDetail( hdr.invno
                           : %date(hdr.crtdate:*iso)
                           : det
                           : %elem(det));
  if count = FAIL;
    DSP1.MSG = invoice_getLastErr();
    return GO_BACK;
  endif;

  eval-corr DSP2C = hdr;
  eval-corr DSP2F = hdr;
  DSP2C.CRTDATE6  = toJobDate(hdr.CRTDATE);
  DSP2C.DELDATE6  = toJobDate(hdr.DELDATE);
  DSP2C.INVDATE6  = toJobDate(hdr.INVDATE);
  DSP2C.PAIDDATE6 = toJobDate(hdr.PAIDDATE);
  DSP2C.PODATE6   = toJobDate(hdr.PODATE);
  eval-corr DSP3C = DSP2C;
  eval-corr DSP3C = hdr;
  eval-corr DSP3F = hdr;

  for i = 1 to count;

    monitor;
      DSP2S.EXTN = %dech(det(i).QTY * det(i).PRICE: 8: 2);
    on-error;
      DSP2S.EXTN = *HIVAL;
    endmon;

    eval-corr DSP2S = det(i);
    RRN2 += 1;
    write INVINQ2S DSP2S;

    eval-corr DSP3S = det(i);
    DSP3S.EXTN = DSP2S.EXTN;

    RRN3 += 1;
    write INVINQ3S DSP3S;

    SFLDSP = *ON;
  endfor;

  HIGHRRN = RRN2;
  return CONTINUE;

end-proc;


//=============================================================
// Show the detailed invoice, allow switching between the
// delivery/billing info.
//=============================================================

dcl-proc showInvoice;

  dcl-pi *n int(10);
    DSP2C likerec(INVINQ2C:*ALL);
    DSP2F likerec(INVINQ2F:*ALL);
    DSP3C likerec(INVINQ3C:*ALL);
    DSP3F likerec(INVINQ3F:*ALL);
  end-pi;

  dcl-s mode char(1) inz('S') static;

  dou EXIT or CANCEL;

    if mode = 'S';
      write INVINQ2F DSP2F;
      exfmt INVINQ2C DSP2C;
    else;
      write INVINQ3F DSP3F;
      exfmt INVINQ3C DSP3C;
    endif;

    DSP2F.MSG = *BLANKS;
    DSP3F.MSG = *BLANKS;

    if EXIT or CANCEL;
      EXIT   = *OFF;
      CANCEL = *OFF;
      return GO_BACK;
    endif;

    if PRINT;
      PRINT = *OFF;
      openURL(DSP2C.INVNO);
    endif;

    if SWITCH_MODE;
      SWITCH_MODE = *OFF;
      if mode = 'B';
        mode = 'S';
      else;
        mode = 'B';
      endif;
    endif;

  enddo;

end-proc;


//=============================================================
// Open a URL to a GUI print of the invoice
//=============================================================

dcl-proc openURL;

  dcl-pi *n int(10);
    invno like(INVHDR_t.invno) const;
  end-pi;

  dcl-s URL varchar(300);
  dcl-s CMD varchar(2000);
  dcl-s needPCO ind inz(*ON) static;

  dcl-pr QCMDEXC  extpgm('QCMDEXC');
    CMD  char(2000) const;
    len  packed(15:5) const;
  end-pr;

  URL = 'http://ibmi.scottklement.com:9999/'
      + %trim(%lower(PSDS.library))
      + '/inv' + %editc(invno:'X') + '.pdf';

  if needPCO;
    CMD = 'STRPCO';
    callp(e) QCMDEXC(CMD:%len(CMD));
    needPCO = *OFF;
  endif;

  CMD = 'STRPCCMD PCCMD(''open ' + URL + ''') PAUSE(*NO)';
  QCMDEXC(CMD:%len(CMD));

  return SUCCESS;
end-proc;


//=============================================================
//  Convert date to job format.
//  If date is not set, make it blank
//=============================================================

dcl-proc toJobDate;

  dcl-pi *n char(8);
    isoDate packed(8: 0) const;
  end-pi;

  dcl-s jobDate char(8);

  select;
  when isoDate = 0 or isoDate = 00010101;
    jobDate = *Blanks;
  when isoDate = 99999999 or isoDate = 99991231;
    jobDate = '+++++++++';
  other;
    jobDate = %char( %date(isoDate:*iso) : *jobrun);
  endsl;

  return jobDate;
end-proc;
