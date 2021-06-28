**free
ctl-opt bnddir('ISYFTP') actgrp('iSYFTP') ;
// ----------------------------------------------------------------------------
// Program.........: ISY_MGET API
// Description.....: FTP made Easy for i - Get multiple files from a dir from requested
// Description.....: FTP Server and stores it locally
// Description.....: LocalDirectory becomes the CURDIR.
// Description.....: LocFileName not used.
// Author..........: Christoffer Öhman
// Created.........: 2020-11-06
// ----------------------------------------------------------------------------

/include ISYFTP/QPROTSRC,ISYFTP

dcl-pi *n ;
  FTP_Options      likeds(T_FTP_Options) ;
  RemoteDirectory  like(T_RemoteDirectory) ;
  RemoteFileName   like(T_RemoteFileName) ;
  LocalDirectory   like(T_LocalDirectory) ;
  LocalFileName    like(T_LocalFileName) ;
  Replace          like(T_Replace) ;
  Remove           like(T_Remove) ;
  ReturnCode       ind ;
end-pi ;

ReturnCode = mget_Files(FTP_Options : RemoteDirectory : RemoteFileName : LocalDirectory : LocalFileName : Replace : Remove) ;

*inlr = *on ;
