**free
ctl-opt bnddir('ISYFTP') actgrp('iSYFTP');
// ------------------------------------------------------------------------------
// Program.........: ISY_PUT API
// Description.....: FTP made Easy for i - Put a file on the requested FTP Server
// Author..........: Mats Lidström
// Created.........: 2020-03-16
// ------------------------------------------------------------------------------

/include ISYFTP/QPROTSRC,ISYFTP


dcl-pi *n;
  FTP_Options      likeDS(T_FTP_Options);
  LocalDirectory   like(T_LocalDirectory);
  LocalFileName    like(T_LocalFileName);
  RemoteDirectory  like(T_RemoteDirectory);
  RemoteFileName   like(T_RemoteFileName);
  Replace          like(T_Replace);
  Remove           like(T_Remove);
  ReturnCode       ind;
end-pi;

  ReturnCode = put_File(FTP_Options : LocalDirectory : LocalFileName : RemoteDirectory : RemoteFileName : Replace : Remove);

*inlr = *on;
