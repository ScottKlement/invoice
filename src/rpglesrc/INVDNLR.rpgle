**free

/if defined(*CRTBNDRPG)
ctl-opt dftactgrp(*no) actgrp(*caller);
/endif
ctl-opt option(*srcstmt:*nodebugio) bnddir('SKLEMENT/QHTTPSVR': 'INVOICE');

/copy ifsio_h
/copy invoice_h

dcl-c PREF  '/invoices/inv';
dcl-c SUFF  '.pdf';
dcl-c FOLDER '/www/scott1/htdocs';
dcl-c CRLF   x'0d25';

dcl-pr QtmhWrStout extproc(*dclcase);
  data pointer value;
  datasize int(10) const;
  rtnsize  int(10);
  errCode  int(20) const;
end-pr;

dcl-pr getenv pointer extproc(*dclcase);
  envvar pointer value options(*string);
end-pr;

dcl-pr invprtr extpgm('INVPRTR');
  invno packed(7: 0) const;
end-pr;

dcl-ds *n;
  rawurl varchar(2000);
  utfurl varchar(2000) ccsid(*utf8) pos(1);
end-ds;

dcl-pr tmpnam pointer extproc('_C_IFS_tmpnam');
  string  Char(39) options(*omit);
end-pr;

dcl-s url     varchar(2000);
dcl-s var     pointer;
dcl-s buffer  char(32768);
dcl-s pos     int(10);
dcl-s stmf    varchar(5000);
dcl-s headers varchar(5000) ccsid(*utf8);
dcl-s rtn     int(10);
dcl-s len     int(10);
dcl-s fd      int(10);
dcl-s temp    varchar(2000);
dcl-s invno   packed(7: 0);

headers = 'Status: 200' + CRLF
        + 'Content-Type: application/pdf; charset=utf8' + CRLF
        + 'Content-Disposition: inline' + CRLF
        + CRLF;
QtmhWrStout(%addr(headers:*data): %len(headers): rtn: 0);

var = getenv('REQUEST_URI');
if var = *null;
  return;
endif;

stmf = %str(tmpnam(*omit)) + '-' + %char(%timestamp());

monitor;
  rawurl = %str(var);
  url = utfurl;
  pos = %scan(PREF:url) + %len(PREF);
  temp = %subst(url:pos);
  pos = %scan(SUFF:temp);
  temp = %subst(temp:1:pos-1);
  invno = %int(temp);
on-error;
  return;
endmon;

monitor;
  if invoice_print(invno: *omit: *omit: stmf) = FAIL;
    return;
  endif;
on-error;
  return;
endmon;

fd = open(stmf: O_RDONLY);
if fd = -1;
  return;
endif;

len = read(fd: %addr(buffer): %size(buffer));
dow len > 0;
  QtmhWrStout(%addr(buffer): len: rtn: 0);
  len = read(fd: %addr(buffer): %size(buffer));
enddo;

callp close(fd);
unlink(stmf);

return;
