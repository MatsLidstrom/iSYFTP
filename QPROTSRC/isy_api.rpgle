**free
//**********************************************************************
//
//  Description..:  iSY_API_PT - Prototypes for iSYFTP API:s
//  Programmer...:  Mats Lidström
//  Date.........:  2018-08-20
//
// *********************************************************************

// Declare Global Template Fields

dcl-ds T_FileList Qualified Template;
  FileName    varchar(132);
  Created     varchar(132);
  Size        varchar(132);
end-ds;

dcl-ds T_FTP_Options Qualified Template
  Host        varchar(132) inz(*blank);
  User        varchar(132) inz(*blank);
  Password    varchar(132) inz(*blank);
  Port        char(10)     inz(*blank);
  Option      varchar(120) inz(*blank);
  Log         char(1)      inz(*blank);
end-ds;

dcl-ds  isy_FTP_Options     likeds(T_FTP_Options);
dcl-s   isy_RemoteDirectory varchar(256) inz(*blank);
dcl-s   isy_Prefix          varchar(20) inz(*blank);
dcl-s   isy_Extension       varchar(20) inz(*blank);
dcl-ds  isy_FileList        likeds(T_FileList) dim(9999);
dcl-s   isy_FileRows        int(5) inz(*zero);
dcl-s   isy_RemoteFileName  varchar(256) inz(*blank);
dcl-s   isy_LocalDirectory  varchar(256) inz(*blank);
dcl-s   isy_LocalFileName   varchar(256) inz(*blank);
dcl-s   isy_Replace         char(1) inz(*blank);
dcl-s   isy_Remove          char(1) inz(*blank);

dcl-s   isy_ReturnCode      ind;


//--------------------------------------------------------------------------//
// @Procedure_Name         : isy_LIST                                       //
// @Procedure_Description  : Lists files on requested FTP Server            //
// @Procedure_Source       : QRPGLESRC/iSY_LIST                             //
//--------------------------------------------------------------------------//

dcl-pr isy_LIST extpgm('ISY_LIST');
  FTP_Options      likeDS(isy_FTP_Options);
  RemoteDirectory  like(isy_RemoteDirectory);
  Prefix           like(isy_Prefix);
  Extension        like(isy_Extension);
  FileList         likeds(isy_FileList) dim(9999);
  FileRows         like(isy_FileRows);
  ReturnCode       like(isy_ReturnCode);
end-pr;


//--------------------------------------------------------------------------//
// @Procedure_Name         : isy_GET                                        //
// @Procedure_Description  : Get a file from the requested FTP Server       //
// @Procedure_Description  : and stores it locally                          //
// @Procedure_Source       : QRPGLESRC/iSY_GET                              //
//--------------------------------------------------------------------------//

dcl-pr isy_GET extpgm('ISY_GET');
  FTP_Options      likeDS(isy_FTP_Options);
  RemoteDirectory  like(isy_RemoteDirectory);
  RemoteFileName   like(isy_RemoteFileName);
  LocalDirectory   like(isy_LocalDirectory);
  LocalFileName    like(isy_LocalFileName);
  Replace          like(isy_Replace);
  Remove           like(isy_Remove);
  ReturnCode       like(isy_ReturnCode);
end-pr;

//--------------------------------------------------------------------------//
// @Procedure_Name         : isy_PUT                                        //
// @Procedure_Description  : Put a file on the requested FTP Server         //
// @Procedure_Source       : QRPGLESRC/iSY_PUT                              //
//--------------------------------------------------------------------------//

dcl-pr isy_PUT extpgm('ISY_PUT');
  FTP_Options      likeDS(isy_FTP_Options);
  LocalDirectory   like(isy_LocalDirectory);
  LocalFileName    like(isy_LocalFileName);
  RemoteDirectory  like(isy_RemoteDirectory);
  RemoteFileName   like(isy_RemoteFileName);
  Replace          like(isy_Replace);
  Remove           like(isy_Remove);
  ReturnCode       like(isy_ReturnCode);
end-pr;

//--------------------------------------------------------------------------//
// @Procedure_Name         : isy_MGET                                       //
// @Procedure_Description  : Get multiple files from a dir from requested   //
// @Procedure_Description  : ftp server and stores it locally in curdir     //
// @Procedure_Source       : iSY_GET                                        //
//--------------------------------------------------------------------------//

dcl-pr isy_MGET extpgm('ISY_MGET');
  FTP_Options      likeDS(isy_FTP_Options);
  RemoteDirectory  like(isy_RemoteDirectory);
  RemoteFileName   like(isy_RemoteFileName);
  LocalDirectory   like(isy_LocalDirectory);
  LocalFileName    like(isy_LocalFileName);
  Replace          like(isy_Replace);
  Remove           like(isy_Remove);
  ReturnCode       like(isy_ReturnCode);
end-pr;
