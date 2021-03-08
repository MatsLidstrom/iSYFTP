**free
//**********************************************************************
//
//  Description..:  iSYFTP - Prototypes for iSYFTP Procedures
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

dcl-ds T_FTP_Options Qualified Template;
    Host                    varchar(132) inz(*blank);
    User                    varchar(132) inz(*blank);
    Password                varchar(132) inz(*blank);
    Port                    char(10)     inz(*blank);
    Option                  varchar(120) inz(*blank);
    Log                     char(1)      inz(*blank);
end-ds;

dcl-s   T_RemoteDirectory   varchar(132) inz(*blank);
dcl-s   T_Prefix            varchar(20)  inz(*blank);
dcl-s   T_Extension         varchar(20)  inz(*blank);
dcl-s   T_FileRows          int(5);
dcl-s   T_RemoteFileName    varchar(132) inz(*blank);
dcl-s   T_LocalDirectory    varchar(132) inz(*blank);
dcl-s   T_LocalFileName     varchar(132) inz(*blank);
dcl-s   T_Replace           char(1)      inz(*blank);
dcl-s   T_Remove            char(1)      inz(*blank);


//--------------------------------------------------------------------------//
// @Procedure_Name         : list_Files                                     //
// @Procedure_Description  : Lists files on requested FTP Server            //
// @Procedure_Source       : QRPGLESRC/iSYFTP                               //
//--------------------------------------------------------------------------//

dcl-pr list_Files ind;
    FTP_Options     likeds(T_FTP_Options) const;
    RemoteDirectory like(T_RemoteDirectory) const;
    Prefix          like(T_Prefix) const;
    Extension       like(T_Extension) const;
    FileList        likeds(T_FileList) dim(9999);
    FileRows        like(T_FileRows);
end-pr;


//--------------------------------------------------------------------------//
// @Procedure_Name         : get_File                                       //
// @Procedure_Description  : Get a file from the requested FTP Server       //
// @Procedure_Description  : and stores it locally                          //
// @Procedure_Source       : QRPGLESRC/iSYFTP                               //
//--------------------------------------------------------------------------//

dcl-pr get_File ind;
    FTP_Options     likeds(T_FTP_Options) const;
    RemoteDirectory like(T_RemoteDirectory) const;
    RemoteFileName  like(T_RemoteFileName) const;
    LocalDirectory  like(T_LocalDirectory) const;
    LocalFileName   like(T_LocalFileName) const;
    Replace         like(T_Replace) const;
    Remove          like(T_Remove) const;
end-pr;

//--------------------------------------------------------------------------//
// @Procedure_Name         : put_File                                       //
// @Procedure_Description  : Put a file on the requested FTP Server         //
// @Procedure_Source       : QRPGLESRC/iSYFTP                               //
//--------------------------------------------------------------------------//

dcl-pr put_File ind;
    FTP_Options     likeds(T_FTP_Options) const;
    LocalDirectory  like(T_LocalDirectory) const;
    LocalFileName   like(T_LocalFileName) const;
    RemoteDirectory like(T_RemoteDirectory) const;
    RemoteFileName  like(T_RemoteFileName) const;
    Replace         like(T_Replace) const;
    Remove          like(T_Remove) const;
end-pr;

//--------------------------------------------------------------------------//
// @Procedure_Name         : mget_Files                                     //
// @Procedure_Description  : Get multiple files from a dir from requested   //
// @Procedure_Description  : FTP Server and stores it locally               //
// @Procedure_Description  : LocalDirectory becomes the CURDIR.             //
// @Procedure_Description  : LocFileName not used.                          //
// @Procedure_Source       : iSYFTP_PR                                      //
//--------------------------------------------------------------------------//

dcl-pr mget_Files ind;
    FTP_Options     likeds(T_FTP_Options) const;
    RemoteDirectory like(T_RemoteDirectory) const;
    RemoteFileName  like(T_RemoteFileName) const;
    LocalDirectory  like(T_LocalDirectory) const;
    LocalFileName   like(T_LocalFileName) const;
    Replace         like(T_Replace) const;
    Remove          like(T_Remove) const;
end-pr;