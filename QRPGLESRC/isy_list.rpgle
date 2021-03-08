**free
ctl-opt bnddir('ISYFTP') actgrp('iSYFTP');
// --------------------------------------------------------------------------
// Program.........: ISY_LIST API
// Description.....: FTP made Easy for i - List files on requested FTP Server
// Author..........: Mats Lidström
// Created.........: 2018-08-19
// --------------------------------------------------------------------------

/include ISYFTP/QPROTSRC,ISYFTP


dcl-pi *n;
  FTP_Options      likeDS(T_FTP_Options);
  RemoteDirectory  like(T_RemoteDirectory);
  Prefix           like(T_Prefix);
  Extension        like(T_Extension) ;
  FileList         likeds(T_FileList) dim(9999);
  FileRows         like(T_FileRows);
  ReturnCode       ind;
end-pi;

  ReturnCode = list_Files(FTP_Options : RemoteDirectory : Prefix : Extension : FileList : FileRows);

*inlr = *on;
