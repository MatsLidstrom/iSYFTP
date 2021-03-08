**free
ctl-opt bnddir('ISYFTP') actgrp('iSYFTP');
// --------------------------------------------------------------------------------
// Program.........: ISY_GET API
// Description.....: FTP made Easy for i - Get a file from the requested FTP Server
// Author..........: Mats Lidström
// Created.........: 2018-08-19
// --------------------------------------------------------------------------------

/include ISYFTP/QPROTSRC,ISYFTP


dcl-pi *n;
  FTP_Options      likeDS(T_FTP_Options);
  RemoteDirectory  like(T_RemoteDirectory);
  RemoteFileName   like(T_RemoteFileName);
  LocalDirectory   like(T_LocalDirectory);
  LocalFileName    like(T_LocalFileName);
  Replace          like(T_Replace);
  Remove           like(T_Remove);
  ReturnCode       ind;
end-pi;

  ReturnCode = get_File(FTP_Options : RemoteDirectory : RemoteFileName : LocalDirectory : LocalFileName : Replace : Remove);

*inlr = *on;
