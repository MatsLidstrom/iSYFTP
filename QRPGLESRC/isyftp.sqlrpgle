**free
ctl-opt nomain;
// -----------------------------------------------------------------------------
// Name............: iSYFTP
// Description.....: FTP made Easy for i
//                   Acts as an FTP Client with a number of basic functions
//
// Author..........: Mats Lidström
// Created.........: 2018-07-28
//
// Version.........: V1.0.0 2018-09-03 - Base version
// Version.........: V1.1.0 2020-03-16 - Added PUT
// Version.........: V2.0.0 2020-05-09 - Added support for SFTP both Public Key Authentication and Password
// Version.........: V2.0.1 2021-02-27 - Structure and some clean up. Also named change (not _PR/_SV/_PT)
// Version.........: V2.0.2 2021-03-01 - mget added for Multiple Get. Thanks Christoffer Öhman!!
// Version.........: V2.0.3 2021-06-24 - Added support for long directory and file names
// Version ........: V2.0.4 2021-06-28 - Set bin mode if PUT from qsys.lib
// Version ........: V2.0.5 2022-12-29 - CPYTOIMPF keyword values RCDDLM(*LF) STRDLM(*NONE) STRESCCHR(*NONE) RMVBLANK(*BOTH)
//                                       set to prevent new default values when upgrading IBM i OS
// Version ........: V2.1.0 2022-12-29 - SSH_ASKPASS_REQUIRE=force added to "export DISPLAY= SSH_ASKPASS_REQUIRE=force SSH_ASKPASS="
//                                       to support IBM i 7.5 and OpenSSH_8.6p1
// Version ........: V2.1.1 2023-08-23 - Removal of Remote Directory and forward slsh from filename in list_Files
// Version ........: V2.1.2 2023-10-15 - Smarter handling of slashes. Removes double slashes in paths
//
// Information of how to use Mode SFTP:
//
// Note! Shell commands can be run via the 5250 Shell Terminal (call qp2term) or via PuTTY on the PC
//
// 1. The user profile of the user that runs the FTP process must be defined with the path to its home directory.
// 2. A directory named .ssh must exist under the users home directory
// 3. The host to make SFTP/SSH connections to must exists in the known_hosts table in the .ssh directory
//    This can be done using the following shell command NOTE! Must be done when logged on with the user that will run the FTP:
//    -   ssh -T "user@host"
// 4. When using Public Key Authentication must the Public Key be generated and setup on the FTP Host side
//    The following shell command is used to generate the Public Key :
//    -   ssh-keygen -t rsa  (type rsa)
//    -   ssh-keygen -t dsa  (type dsa)
//    Share the generated Public Key with the host side:
//    -   id_rsa.pub (type rsa)
//    -   id_dsa.pub (type dsa)
//
//  https://www.ibm.com/support/pages/configuring-ibm-i-ssh-sftp-and-scp-clients-use-public-key-authentication
//
// -----------------------------------------------------------------------------

/include ISYFTP/QPROTSRC,ISYFTP

// Program Status Datastructure
dcl-ds pgm_stat PSDS Qualified;
  status   *STATUS;
  routine  *ROUTINE;
  library  char(10) pos(81);
  jobname  char(10) pos(244);
  user     char(10) pos(254);
  jobno    zoned(6) pos(264);
  program  char(10) pos(334);
  curruser char(10) pos(358);
end-ds;

// Declare Global Datastructures
dcl-ds  FTP_Log Qualified  dim(9999);
    LogData     char(1024);
end-ds;

// Declare Global Variables
dcl-s   Command             varchar(256);
dcl-s   FTP_Command         char(1024);
dcl-s   FTP_Command_List    char(1024) dim(99);
dcl-s   FTPCommandRows      int(5);
dcl-s   LogRows             int(5);

dcl-s   gblTempDir          varchar(128);
dcl-s   gblRootDir          varchar(128);
dcl-s   gblSFTP             ind;
dcl-s   gblPasswordUsed     ind;
dcl-s   gblLog              like(T_FTP_Options.Log);
dcl-s   gblTimestamp        timestamp;

dcl-c   cTrue               '1';
dcl-c   cFalse              '0';
dcl-c   cQuote              '''';


// -----------------------------------------------------------------------------
// Procedure.......: list_Files
// Description.....: Lists files on requested FTP Server
// -----------------------------------------------------------------------------
dcl-proc list_Files export;

  dcl-pi *n ind;
    FTP_Options     likeds(T_FTP_Options) const;
    RemoteDirectory like(T_RemoteDirectory) const;
    Prefix          like(T_Prefix) const;
    Extension       like(T_Extension) const;
    FileList        likeds(T_FileList) dim(9999);
    FileRows        like(T_FileRows);
  end-pi;

    dcl-s   wStart  int(5);
    dcl-s   wEnd    int(5);
    dcl-s   i       int(5);
    dcl-s   wPrefix                 like(Prefix);
    dcl-s   wExtension              like(Extension);

    dcl-s   Host                    like(FTP_Options.Host);
    dcl-s   User                    like(FTP_Options.User);
    dcl-s   Password                like(FTP_Options.Password);
    dcl-s   Port                    like(FTP_Options.Port);
    dcl-s   Option                  like(FTP_Options.Option);
    dcl-s   Log                     like(FTP_Options.Log);

    Host = FTP_Options.Host;
    User = FTP_Options.User;
    Password = FTP_Options.Password;
    Port = FTP_Options.Port;
    Option = FTP_Options.Option;
    Log = FTP_Options.Log;

    // Set Global values to be used by other procedures
    set_GlobalIndicators(FTP_Options);

    // Init
    clear   FileList;
    FileRows = *zero;
    wStart = *zero;
    wEnd = *zero;

    // prepare FTP Commands
    clear FTP_Command_List; // Init
    FTPCommandRows = *zero; // Init

    wPrefix = Prefix;

    if wPrefix = *blanks; // Not Set
      wPrefix = '*';    // All Default
    else;
      if wPrefix <> '*'; // Not set to all already
        wPrefix = %trim(wPrefix) + '*';
      endif;
    endif;

    wExtension = Extension;

    if wExtension = *blanks; // Not Set
      wExtension = '*';    // All Default
    endif;

    if RemoteDirectory = *blank;
      FTP_Command = 'ls ' +  %trim(wPrefix) + '.' + %trim(wExtension); // List files
    else;
      FTP_Command = 'ls ' +  %trim(RemoteDirectory) + '/' + %trim(wPrefix) + '.' + %trim(wExtension); // List files
      FTP_Command = %scanrpl('//':'/':FTP_Command);
    endif;

    prepare_FTPcmd(FTP_Command);

    if not setnrun_FTPcmd(Host: User : Password : Port : Option );
      store_FTPLog('Error');
      return cFalse; // Error
    else;

      if gblSFTP;
        get_FileNamesFromLog_SFTP(RemoteDirectory);
      endif;

      // 150 = Start  List
      // 226 = End List

      // Get the list of files from the FTP Log
      wStart = check_FTPCode('150');
      if wStart = 0;
        wStart = check_FTPCode('125');
      endif;
      if wStart > *zero; // Start of File Block found

        wEnd = check_FTPCode('226' : wStart);
        if wEnd = 0;
          wEnd = check_FTPCode('250' : wStart);
        endif;
        if wEnd > *zero; // End of File Block found

          if wStart + 1 < wEnd; // Files exists (not just Start and End Block)

            // Get Filenames from FTP Log for Return List. Remove of possible RemoteDirectory and forward slash
            for i = wStart + 1 to wEnd - 1;
              FileRows =  FileRows + 1;
              FileList(FileRows).FileName = %scanrpl(%trim(RemoteDirectory) + '/' : '' : FTP_Log(i).LogData);
              FileList(FileRows).FileName = %scanrpl('/' : '' : FileList(FileRows).FileName);
            endfor;

          endif;

        endif;
      endif;

      if Log = 'Y' or Log = 'D';
        store_FTPLog('Ok');
      endif;

      return cTrue; // OK
    endif;

    on-exit;
      delete_TempDir_SFTP();

end-proc;


// -----------------------------------------------------------------------------
// Procedure.......: get_File
// Description.....: Get a file from the requested FTP Server and stores it locally
// -----------------------------------------------------------------------------
dcl-proc get_File export;

  dcl-pi *n ind;
    FTP_Options     likeds(T_FTP_Options) const;
    RemoteDirectory like(T_RemoteDirectory) const;
    RemoteFileName  like(T_RemoteFileName) const;
    LocalDirectory  like(T_LocalDirectory) const;
    LocalFileName   like(T_LocalFileName) const;
    Replace         like(T_Replace) const;
    Remove          like(T_Remove) const;
  end-pi;

    dcl-s   wLocalFileNameWithPath  varchar(256);
    dcl-s   wRemoteFileNameWithPath varchar(256);
    dcl-s   Host                    like(FTP_Options.Host);
    dcl-s   User                    like(FTP_Options.User);
    dcl-s   Password                like(FTP_Options.Password);
    dcl-s   Port                    like(FTP_Options.Port);
    dcl-s   Option                  like(FTP_Options.Option);
    dcl-s   Log                     like(FTP_Options.Log);


    Host = FTP_Options.Host;
    User = FTP_Options.User;
    Password = FTP_Options.Password;
    Port = FTP_Options.Port;
    Option = FTP_Options.Option;
    Log = FTP_Options.Log;

    // Set Global values to be used by other procedures
    set_GlobalIndicators(FTP_Options);

    // prepare FTP Commands
    clear FTP_Command_List; // Init
    FTPCommandRows = *zero; // Init

    if LocalDirectory <> *blanks;
      wLocalFileNameWithPath = %trim(LocalDirectory) + '/' + %trim(LocalFileName); // Set File with Path
      wLocalFileNameWithPath = %scanrpl('//':'/':wLocalFileNameWithPath);
    endif;

    if RemoteDirectory <> *blanks;
      wRemoteFileNameWithPath = %trim(RemoteDirectory) + '/' + %trim(RemoteFileName); // Set File with Path
      wRemoteFileNameWithPath = %scanrpl('//':'/':wRemoteFileNameWithPath);
    else;
      wRemoteFileNameWithPath = %trim(RemoteFileName); // Just filename
    endif;

    if not gblSFTP;
      FTP_Command = 'namefmt 1'; // Change File Name Format to IBM i IFS Style
      prepare_FTPcmd(FTP_Command);
    endif;

    FTP_Command = 'get ' + %trim(wRemoteFileNameWithPath) + ' ' + %trim(wLocalFileNameWithPath); // Get File
    if Replace = 'Y';
      FTP_Command = %trim(FTP_Command) + ' (replace';
    endif;

    prepare_FTPcmd(FTP_Command);

    if not setnrun_FTPcmd(Host: User : Password : Port : Option);
      store_FTPLog('Error');
      return cFalse; // Error
    else;

      // 226 = Complete Transfer

      // Check if successful GET
      if check_FTPCode('226') > *zero;
        if Log = 'Y' or Log = 'D';
            store_FTPLog('Ok');
        endif;

        // Remove of downloaded file requested
        if Remove = 'Y';

          // Delete the Temp Directory used for the Get Command
          delete_TempDir_SFTP();

          // Set Global values to be used by other procedures
          set_GlobalIndicators(FTP_Options);

          if gblSFTP;
            FTP_Command = 'rm ' + %trim(wRemoteFileNameWithPath);
          else;
            FTP_Command = 'delete ' + %trim(wRemoteFileNameWithPath);
          endif;

          FTP_Command_List(FTPCommandRows) = FTP_Command; // Replace prepared GET with DELETE

          if not setnrun_FTPcmd(Host: User : Password : Port : Option);
            store_FTPLog('Error');
            return cFalse; // Error
          else;
            if Log = 'Y' or Log = 'D';
              store_FTPLog('Ok');
            endif;
          endif;
        endif;

        return cTrue;
      else;
        store_FTPLog('Error');
        return cFalse;
      endif;

    endif;

    on-exit;
      delete_TempDir_SFTP();

end-proc;


// -----------------------------------------------------------------------------
// Procedure.......: mget_Files
// Description.....: Get multiple files from a dir from requested FTP Server and stores it locally
//                   LocalDirectory becomes the CURDIR. LocFileNAme not used.
// -----------------------------------------------------------------------------
dcl-proc mget_Files Export;

  dcl-pi *n ind;
    FTP_Options     likeds(T_FTP_Options) const;
    RemoteDirectory like(T_RemoteDirectory) const;
    RemoteFileName  like(T_RemoteFileName) const;
    LocalDirectory  like(T_LocalDirectory) const;
    LocalFileName   like(T_LocalFileName) const;    // Not used for now
    Replace         like(T_Replace) const;
    Remove          like(T_Remove) const;
  end-pi;

    dcl-s   wLocalFileNameWithPath  varchar(256);
    dcl-s   wRemoteFileNameWithPath varchar(256);
    dcl-s   Host                    like(FTP_Options.Host);
    dcl-s   User                    like(FTP_Options.User);
    dcl-s   Password                like(FTP_Options.Password);
    dcl-s   Port                    like(FTP_Options.Port);
    dcl-s   Option                  like(FTP_Options.Option);
    dcl-s   Log                     like(FTP_Options.Log);

    Host = FTP_Options.Host;
    User = FTP_Options.User;
    Password = FTP_Options.Password;
    Port = FTP_Options.Port;
    Option = FTP_Options.Option;
    Log = FTP_Options.Log;

    // Set Global values to be used by other procedures
    set_GlobalIndicators(FTP_Options);

    // prepare FTP Commands
    clear FTP_Command_List; // Init
    FTPCommandRows = *zero; // Init

    if not gblSFTP;
      FTP_Command = 'namefmt 1'; // Change File Name Format to IBM i IFS Style
      prepare_FTPcmd(FTP_Command);
    endif;

    if LocalDirectory <> *blanks ;
      if %scanr('/':LocalDirectory) < %len(%trim(LocalDirectory));   // Handle trailing /
        wLocalFileNameWithPath = %trim(LocalDirectory) + '/';
      else;
        wLocalFileNameWithPath = %trim(LocalDirectory);
      endIf;

      FTP_Command = 'lcd ' + %trim(wLocalFileNameWithPath) ; // Change target directory
      prepare_FTPcmd(FTP_Command);
    endif;

    if RemoteDirectory <> *blanks ;
      wRemoteFileNameWithPath = %trim(RemoteDirectory) + '/' + %trim(RemoteFileName); // Set File with Path
      wRemoteFileNameWithPath = %scanrpl('//':'/':wRemoteFileNameWithPath);
    else;
      wRemoteFileNameWithPath = %trim(RemoteFileName); // Just filename
    endif;


    FTP_Command = 'mget ' + %trim(wRemoteFileNameWithPath) ; // Get File. Always assumes CurLib or CurDIR in namefmt 1
    if Replace = 'Y';
      FTP_Command = %trim(FTP_Command) + ' (replace';
    endif;
    prepare_FTPcmd(FTP_Command);


    if not setnrun_FTPcmd(Host: User : Password : Port : Option);
      store_FTPLog('Error');
      return cFalse; // Error
    else;

      // 226 = Complete Transfer

      // Check if successful GET
      if check_FTPCode('226') > *zero;
        if Log = 'Y' or Log = 'D';
          store_FTPLog('Ok');
        endif;

        // Remove of downloaded file requested
        if Remove = 'Y';

          // Delete the Temp Directory used for the Get Command
          delete_TempDir_SFTP();

          // Set Global values to be used by other procedures
          set_GlobalIndicators(FTP_Options);

          if gblSFTP;
            FTP_Command = 'rm ' + %trim(wRemoteFileNameWithPath);
          else;
            FTP_Command = 'delete ' + %trim(wRemoteFileNameWithPath);
          endif;

          FTP_Command_List(FTPCommandRows) = FTP_Command; // Replace prepared GET with DELETE

          if not setnrun_FTPcmd(Host: User : Password : Port : Option);
            store_FTPLog('Error');
            return cFalse; // Error
          else;
            if Log = 'Y' or Log = 'D';
              store_FTPLog('Ok');
            endif;
          endif;
        endif;

        return cTrue;
      else;
        store_FTPLog('Error');
        return cFalse;
      endif;

    endif;

    on-exit;
      delete_TempDir_SFTP();

end-proc;


// -----------------------------------------------------------------------------
// Procedure.......: put_File
// Description.....: Put a file that is stored locally on the requested FTP Server
// -----------------------------------------------------------------------------
dcl-proc put_File export;

  dcl-pi *n ind;
    FTP_Options     likeds(T_FTP_Options) const;
    LocalDirectory  like(T_LocalDirectory) const;
    LocalFileName   like(T_LocalFileName) const;
    RemoteDirectory like(T_RemoteDirectory) const;
    RemoteFileName  like(T_RemoteFileName) const;
    Replace         like(T_Replace) const;
    Remove          like(T_Remove) const;
  end-pi;

    dcl-s   wLocalFileNameWithPath  varchar(256);
    dcl-s   wRemoteFileNameWithPath varchar(256);
    dcl-s   Host                    like(FTP_Options.Host);
    dcl-s   User                    like(FTP_Options.User);
    dcl-s   Password                like(FTP_Options.Password);
    dcl-s   Port                    like(FTP_Options.Port);
    dcl-s   Option                  like(FTP_Options.Option);
    dcl-s   Log                     like(FTP_Options.Log);


    Host = FTP_Options.Host;
    User = FTP_Options.User;
    Password = FTP_Options.Password;
    Port = FTP_Options.Port;
    Option = FTP_Options.Option;
    Log = FTP_Options.Log;

    // Set Global values to be used by other procedures
    set_GlobalIndicators(FTP_Options);

    // prepare FTP Commands
    clear FTP_Command_List; // Init
    FTPCommandRows = *zero; // Init


    if LocalDirectory <> *blanks;
      wLocalFileNameWithPath = %trim(LocalDirectory) + '/' + %trim(LocalFileName); // Set File with Path
      wLocalFileNameWithPath = %scanrpl('//':'/':wLocalFileNameWithPath);      
    endif;

    if RemoteDirectory <> *blanks;
      wRemoteFileNameWithPath = %trim(RemoteDirectory) + '/' + %trim(RemoteFileName); // Set File with Path
      wRemoteFileNameWithPath = %scanrpl('//':'/':wRemoteFileNameWithPath); 
    else;
      wRemoteFileNameWithPath = %trim(RemoteFileName); // Just filename
    endif;

    if not gblSFTP;
      FTP_Command = 'namefmt 1'; // Change File Name Format to IBM i IFS Style
      prepare_FTPcmd(FTP_Command);
    endif;

    if %scan('qsys.lib' : LocalDirectory) > *zero;
      FTP_Command = 'bin'; // Set Binary Mode IBM i Save File
      prepare_FTPcmd(FTP_Command);
    endif;

    FTP_Command = 'put ' + %trim(wLocalFileNameWithPath) + ' ' + %trim(wRemoteFileNameWithPath); // Put File
    prepare_FTPcmd(FTP_Command);

    if not setnrun_FTPcmd(Host: User : Password : Port : Option);
      store_FTPLog('Error');
      return cFalse; // Error
    else;

      // 226 = Complete Transfer

      // Check if successful PUT
      if check_FTPCode('226') > *zero;
        if Log = 'Y' or Log = 'D';
          store_FTPLog('Ok');
        endif;

        // Remove of sent file
        if Remove = 'Y';
          Command = 'RMVLNK OBJLNK(' + cQuote + %trim(wLocalFileNameWithPath) + cQuote + ')';
        endif;

        return cTrue;
      else;
        store_FTPLog('Error');
        return cFalse;
      endif;

    endif;

    on-exit;
      delete_TempDir_SFTP();

end-proc;


// -----------------------------------------------------------------------------
// Procedure.......: set_GlobalIndicators
// Description.....: Set Global indicators to be used by other procedures
/// -----------------------------------------------------------------------------
dcl-proc set_GlobalIndicators;

  dcl-pi *n;
    FTP_Options     likeds(T_FTP_Options) const;
  end-pi;

    if FTP_Options.Option = 'SFTP';
      gblSFTP = cTrue;
    else;
      gblSFTP = cFalse;
    endif;

    if FTP_Options.Password = *blank;
      gblPasswordUsed = cFalse;
    else;
      gblPasswordUsed = cTrue;
    endif;

    gblLog = FTP_Options.Log;

    gblTimestamp = %timestamp;

    // Set the Root Director for the iSYFTP files. Note that it has to end with /
    // Default is The Root /
    gblRootDir = '/';

    return;

end-proc;


// -----------------------------------------------------------------------------
// Procedure.......: setnrun_FTPcmd
// Description.....: Set and Run Requested FTP Commands
/// -----------------------------------------------------------------------------
dcl-proc setnrun_FTPcmd;

  dcl-pi *n ind;
    Host            like(T_FTP_Options.Host) const;
    User            like(T_FTP_Options.User) const;
    Password        like(T_FTP_Options.Password) const;
    Port            like(T_FTP_Options.Port) const;
    Option          like(T_FTP_Options.Option) const;
  end-pi;

    // Declare Valiables
    dcl-s i             int(5);

    exec sql SET OPTION COMMIT = *NONE, CLOSQLCSR = *ENDMOD, DATFMT = *ISO;

    init_FTPworkfiles();

    if not ftpcmd_Login(Host : User : Password : Port : Option);
      if not gblSFTP;
        clear_FTPcmdFile(); // Clear FTP Commands when used
      endif;
      return cFalse;
    else;

      if not gblSFTP;
        clear_FTPlogFile(); // Before continue
      endif;

      // Insert Prepared FTP Commands
      for i = 1 to FTPCommandRows;
        FTP_Command = FTP_Command_List(i);
        insert_FTPcmd(FTP_Command);
      endfor;

      FTP_Command = 'quit'; // Quit Connection
      insert_FTPcmd(FTP_Command);

      // Run prepared FTP Commands placed in FTP Command/Script Workfile
      run_FTPcmd(Host : User : Password : Port : Option);
      if gblSFTP;
        // Check if SFTP connection failed
        if not check_ResponseCode_SFTP();
          return cFalse;
        endif;
      else;
        clear_FTPcmdFile(); // Clear FTP Commands when used
      endif;
    endif;

    return cTrue;

end-proc;


// -----------------------------------------------------------------------------
// Sub Procedure...: ftpcmd_Login
// Description.....: Login to requested Server
// -----------------------------------------------------------------------------
dcl-proc ftpcmd_Login;

  dcl-pi *n ind;
    Host            like(T_FTP_Options.Host) const;
    User            like(T_FTP_Options.User) const;
    Password        like(T_FTP_Options.Password) const;
    Port            like(T_FTP_Options.Port) const;
    Option          like(T_FTP_Options.Option) const;
  end-pi;

    if gblSFTP;
      // Set and create the Temp Directory to be used by the SFTP process
      gblTempDir =  %trim(gblRootDir) + 'isyftp/temp/' + %char(gblTimestamp) + '/';
      Command = 'crtdir dir(' + cQuote + %trim(gblTempDir) + cQuote + ')';
      exec_Command(Command);

      // Set Password if used
      if gblPasswordUsed;
        if not prep_Password_SFTP(Password);
          return cFalse;
        endif;
      endif;

      return cTrue;
    else;
      FTP_Command = %trim(User) + ' ' + %trim(Password); // User and Password
      insert_FTPcmd(FTP_Command);

      run_FTPcmd(Host : User : Password : Port : Option); // Run prepared FTP Commands placed in FTP Command Workfile

      // UNIX Type: L8
      // 230 Successful login

      if check_FTPCode('230') > *zero; // Successful login
        return cTrue;
      else;
        return cFalse;
      endif;
    endif;

end-proc;


// -----------------------------------------------------------------------------
// Sub Procedure...: run_FTPcmd
// Description.....: Run FTP Commands
// -----------------------------------------------------------------------------
dcl-Proc run_FTPcmd;

  dcl-pi *n;
    Host            like(T_FTP_Options.Host) const;
    User            like(T_FTP_Options.User) const;
    Password        like(T_FTP_Options.Password) const;
    Port            like(T_FTP_Options.Port) const;
    Option          like(T_FTP_Options.Option) const;
  end-pi;

    // Delcare Program Interfaces !! CL Program with OVRDBF !!
    dcl-pr FTPrun_CMD extpgm('ISYRUNCMD');
      *n char(120) const;
      *n char(10) const;
      *n char(120) const;
    end-pr;

    if gblSFTP;
      SFTPrun_CMD(Host : User : Password : Port : Option); // Run prepared SFTP Commands placed in FTP Scriptfile
    else;
      FTPrun_CMD(%trimr(Host) : Port : Option); // Run prepared FTP Commands placed in FTP Command Workfile
    endif;

    if gblSFTP;
      LogRows = 1;

      if check_ResponseCode_SFTP();
        FTP_Log(LogRows) = '226';
      else;
        FTP_Log(LogRows) = '400';
      endif;

    else;
      LogRows = %elem(FTP_Log);

      // Get FTP Logg to DS List
      exec sql DECLARE C0 CURSOR FOR SELECT SRCDTA as LogData FROM QTEMP.iSYFTPlog FOR READ ONLY;
      exec sql OPEN C0;
      exec sql FETCH C0 FOR :LogRows ROWS INTO :FTP_Log;
      exec sql GET DIAGNOSTICS :LogRows = ROW_COUNT;
      exec sql CLOSE C0;
    endif;

    return;

end-proc;


// -----------------------------------------------------------------------------
// Sub Procedure...: SFTPrun_cmd
// Description.....: Run SFTP Commands
// -----------------------------------------------------------------------------
dcl-Proc SFTPrun_cmd;

  dcl-pi *n;
    Host            like(T_FTP_Options.Host) const;
    User            like(T_FTP_Options.User) const;
    Password        like(T_FTP_Options.Password) const;
    Port            like(T_FTP_Options.Port) const;
    Option          like(T_FTP_Options.Option) const;
  end-pi;

    // Place the FTP script file on the IFS
    Command = 'CPYTOIMPF FROMFILE(QTEMP/XYZ269) TOSTMF(' + cQuote + %trim(gblTempDir) + 'ftp_batch_scripts.sh' +
                cQuote + ') MBROPT(*REPLACE) STMFCCSID(1208) ' +
              'RCDDLM(*LF) STRDLM(*NONE) STRESCCHR(*NONE) RMVBLANK(*BOTH)';
    exec_Command(Command);

    clear_FTPcmdFile();

    // Run the FTP scripts in SFTP mode
    if gblPasswordUsed;
      // Using Password
      prep_PasswordScript_SFTP(Host : User);
      // Execute the Connection and FTP scripts
      Command = 'QSH CMD(' + cQuote + 'exec /QOpenSys/usr/bin/ksh -c "' +
                %trim(gblTempDir) + 'sftp_password_script.sh"' + cQuote + ')';
    else;
      // Using Public Key Authentication
      Command = 'QSH CMD(' + cQuote + '/QOpenSys/usr/bin/sftp -b ' + %trim(gblTempDir) +
                'ftp_batch_scripts.sh '  +  %trim(User) + '@' + %trim(Host) +
                ' > ' + %trim(gblTempDir) + 'log.txt 2>&1' + cQuote + ')';
    endif;

    exec_Command(Command);

end-proc;

//----------------------------------------------------------------------
// Name ...... : prep_PasswordScript_SFTP
// Description : Prepare the Connection with Password scripts
//----------------------------------------------------------------------
dcl-proc prep_PasswordScript_SFTP;

  dcl-pi *n;
    inHost      char(128) const;
    inUser      char(128) const;
  end-pi;

  dcl-s   locCommand          like(FTP_Command);

    // Take the FTP command from the first element in the FTP_Command_List datastructure
    locCommand = FTP_Command_List(1);

    // Set the Connection with Password scripts in the Table
    exec sql
      INSERT INTO SESSION.XYZ269 (Script)
        VALUES('#!/bin/sh'),
              ('export DISPLAY= SSH_ASKPASS_REQUIRE=force SSH_ASKPASS=' CONCAT TRIM(:gblTempDir) CONCAT 'hm.sh'),
              ('printf "' CONCAT TRIM(:locCommand) CONCAT '" | sftp ' CONCAT
               TRIM(:inUser) CONCAT '@' CONCAT TRIM(:inHost) CONCAT
               ' > ' CONCAT TRIM(:gblTempDir) CONCAT 'log.txt 2>&1');

    // Place the FTP Script file on the IFS
    Command = 'CPYTOIMPF FROMFILE(QTEMP/XYZ269) TOSTMF(' + cQuote + %trim(gblTempDir) + 'sftp_password_script.sh' +
                cQuote + ') MBROPT(*REPLACE) STMFCCSID(1208) ' +
              'RCDDLM(*LF) STRDLM(*NONE) STRESCCHR(*NONE) RMVBLANK(*BOTH)';
    exec_Command(Command);

  return;

end-proc;


// -----------------------------------------------------------------------------
// Sub Procedure...: check_FTPCode
// Description.....: Check/Locate FTP Code
// -----------------------------------------------------------------------------
dcl-proc check_FTPCode;

  dcl-pi *n int(5);
    inFTPCode    char(3) const;
    inFrom       int(5)  const options(*nopass);
  end-pi;

    dcl-s   wFTPCode    like(inFTPCode);
    dcl-s   i           like(inFrom);

    clear wFTPCode;
    if %parms = 1;
      i = 1;
    else;
      i = inFrom;
    endif;

    dow i <= LogRows and wFTPCode <> inFTPCode;
      wFTPCode = %subst(FTP_Log(i).LogData : 1 : 4);
      i = i + 1;
    enddo;

    if wFTPCode = inFTPCode;
      i = i - 1;
    else;
      i = *zero;
    endif;

    return i;

end-proc;


//----------------------------------------------------------------------
// Name ...... : check_ResponseCode_SFTP
// Description : Check response code for the FTP connection
//               Return false if FTP Status is other than 0
//----------------------------------------------------------------------
dcl-proc check_ResponseCode_SFTP;

  dcl-pi *n ind;
  end-pi;

    dcl-s ResponseMessage varchar(256);

    exec sql
    SELECT CHAR(Message_Text) INTO :ResponseMessage
      FROM TABLE(qsys2.joblog_info('*')) WHERE From_Library ='QSHELL'
      ORDER BY Message_Timestamp DESC LIMIT 1;

    if sqlcode <> 0;
      clear ResponseMessage;
    endif;

    if %scan('status 0' : ResponseMessage) = 0;
      return cFalse;
    else;
      return cTrue;
    endif;

end-proc;


// -----------------------------------------------------------------------------
// Sub Procedure...: clear_FTPcmdFile
// Description.....: Clear FTP Commands when used
// -----------------------------------------------------------------------------
dcl-proc clear_FTPcmdFile;

  if gblSFTP;
    exec sql DELETE FROM SESSION.XYZ269;
  else;
    Command = 'CLRPFM FILE(QTEMP/iSYFTPcmd) MBR(data)';
    exec_Command(Command);
  endif;

  return;

end-proc;


// -----------------------------------------------------------------------------
// Sub Procedure...: clear_FTPlogFile
// Description.....: Clear FTP logfile before continue
// -----------------------------------------------------------------------------
dcl-proc clear_FTPlogFile;

  dcl-pi *n;
  end-pi;

  Command = 'CLRPFM FILE(QTEMP/iSYFTPlog)';
  exec_Command(Command);

  return;

end-proc;


// -----------------------------------------------------------------------------
// Sub Procedure...: init_FTPworkfiles
// Description.....: Initiate FTP Command and Log Workfiles
// -----------------------------------------------------------------------------
dcl-proc init_FTPworkfiles;

  dcl-pi *n;
  end-pi;

    clear_FTPworkfiles();

    if gblSFTP;
      exec sql
        DECLARE GLOBAL TEMPORARY TABLE SESSION.XYZ269
          (Script CHAR(1024) NOT NULL);
    else;
      Command = 'CRTSRCPF FILE(QTEMP/iSYFTPcmd) RCDLEN(1024) MBR(data)';
      exec_Command(Command);

      Command = 'CRTSRCPF FILE(QTEMP/iSYFTPlog) RCDLEN(1024) MBR(data)';
      exec_Command(Command);
    endif;

    return;

end-proc;


// -----------------------------------------------------------------------------
// Sub Procedure...: clear_FTPworkfiles
// Description.....: Clear FTP Command and Log Workfiles
// -----------------------------------------------------------------------------
dcl-proc clear_FTPworkfiles;

  dcl-pi *n;
  end-pi;

    if gblSFTP;
        delete_TempTable_SFTP();
    else;
        exec sql DROP TABLE QTEMP.iSYFTPcmd;
        exec sql DROP TABLE QTEMP.iSYFTPlog;
    endif;

    return;

end-proc;


// -----------------------------------------------------------------------------
// Sub Procedure...: prepare_FTPcmd
// Description.....: Prepare FTP Command for the FTP Command Workfile
// -----------------------------------------------------------------------------
dcl-proc prepare_FTPcmd;

  dcl-pi *n;
      inFTP_Command   like(FTP_Command) const;
  end-pi;

    FTPCommandRows = FTPCommandRows + 1;

    FTP_Command_List(FTPCommandRows) = inFTP_Command;

    return;

end-proc;


// -----------------------------------------------------------------------------
// Sub Procedure...: insert_FTPcmd
// Description.....: Insert FTP Command to FTP Command Workfile
// -----------------------------------------------------------------------------
dcl-proc insert_FTPcmd;

  dcl-pi *n;
      inFTP_Command   like(FTP_Command) const;
  end-pi;

    if gblSFTP;
      exec sql INSERT INTO SESSION.XYZ269 (Script) VALUES(:inFTP_Command);
    else;
      exec sql INSERT INTO QTEMP.iSYFTPcmd (SRCDTA) VALUES(:inFTP_Command);
    endif;

    return;

end-proc;

// -----------------------------------------------------------------------------
// Sub Procedure...: store_FTPLog
// Description.....: Store the FTP Log on the IFS
// -----------------------------------------------------------------------------
dcl-proc store_FTPLog;

  dcl-pi *n;
    LogType char(10) const;
  end-pi;

    dcl-s   LogDirectory    varchar(132) inz(*blank);

    if LogType = 'Error';
      LogDirectory = %trim(gblRootDir) + 'iSYFTP/Error/';
    else;
      LogDirectory = %trim(gblRootDir) + 'iSYFTP/Log/';
    endif;

    // Store FTP Log on ISF
    if gblSFTP;
      // Set correct name
      Command = 'REN OBJ(' + cQuote + %trim(gblTempDir) + 'log.txt' + cQuote +
                ') NEWOBJ(' + cQuote + %char(gblTimestamp) + '.log' + cQuote + ')';
      exec_Command(Command);

      // Copy jobs SFTP Logfile from Temp to Log Directory
      Command = 'CPY OBJ(' + cQuote + %trim(gblTempDir) + %char(gblTimestamp) + '.log' + cQuote +
                ') TODIR(' + cQuote + %trim(LogDirectory) + cQuote + ')';
      exec_Command(Command);
    else;
      Command = 'CPYTOSTMF FROMMBR(' + cQuote + '/QSYS.LIB/QTEMP.LIB/ISYFTPLOG.FILE/DATA.MBR' + cQuote + ') ' +
                'TOSTMF(' + cQuote + %trim(LogDirectory) + %char(gblTimestamp) + '.log' + cQuote + ') ' +
                'STMFOPT(*REPLACE) DBFCCSID(*FILE) STMFCCSID(1208)';
      exec_Command(Command);
    endif;

    return;

end-proc;


// -----------------------------------------------------------------------------
// Name ...... : get_FileNamesFromLog_SFTP
// Description : Get the File Names from the SFTP Log
// -----------------------------------------------------------------------------
dcl-proc get_FileNamesFromLog_SFTP;

  dcl-pi *n;
    inRemoteDirectory  like(T_RemoteDirectory) const;
  end-pi;

    dcl-ds  SFTP_Log Qualified  dim(9999);
      String           char(1024);
    end-ds;

    dcl-s  locRemoteDirectory  like(inRemoteDirectory);
    dcl-s  locFileName         char(256);
    dcl-s  locRows             int(5);
    dcl-s  locStart            int(5);
    dcl-s  i                   int(5);
    dcl-s  y                   int(5);


    locRemoteDirectory = %trim(inRemoteDirectory) + '/';
    locRemoteDirectory = %scanrpl('//':'/':locRemoteDirectory); 

    Command = 'CPYFRMIMPF FROMSTMF(' + cQuote + %trim(gblTempDir) + 'log.txt' + cQuote + ') ' +
              'TOFILE(QTEMP/XYZ269) MBROPT(*REPLACE) RCDDLM(*LF) DTAFMT(*DLM)';
    exec_Command(Command);

    locRows = %elem(SFTP_Log);

    // Get SFTP Logg to DS List
    exec sql DECLARE C1 CURSOR FOR SELECT Script as String FROM QTEMP.XYZ269
                                      WHERE Script NOT LIKE '%not found%'
                                      FOR READ ONLY;
    exec sql OPEN C1;
    exec sql FETCH C1 FOR :locRows ROWS INTO :SFTP_Log;
    exec sql GET DIAGNOSTICS :locRows = ROW_COUNT;
    exec sql CLOSE C1;


    // Move filenames from SFTP Log to FTP_Log datastructure
    clear y;
    clear FTP_Log;
    locStart = 1;

    LogRows = 1;
    FTP_Log(LogRows).LogData = '150'; // Filelist start

    for i = 1 to locRows;
      if %subst(SFTP_Log(i).String : 1 : 8)  = 'sftp> ls';
        y = i;
      endif;

      if y > 0 and i > y;

        // First remove possible Remote Directory from File Names
        SFTP_Log(i).String = %scanrpl(%trim(locRemoteDirectory) : '' : SFTP_Log(i).String);

        // Get Filenames from Log string
        locStart = 1;
        dow locStart <=  %len(%trim(SFTP_Log(i).String));
          // Get filenames from Log string
          locFileName = get_FileNameFromString(SFTP_Log(i).String : locStart);
          if locFileName <> *blanks;
            LogRows = LogRows + 1;
            FTP_Log(LogRows).LogData = locFileName;
            locStart = get_NextStartPos(SFTP_Log(i).String : locStart + %len(%trim(locFileName)));
          else;
            leave;
          endif;
        enddo;

      endif;

    endfor;

    LogRows = LogRows + 1;
    FTP_Log(LogRows).LogData = '226'; // Filelist end

  return;

end-proc;


// -----------------------------------------------------------------------------
// Name ...... : get_NextStartPos;
// Description : Get start position for next filename
// -----------------------------------------------------------------------------
dcl-proc get_NextStartPos;

  dcl-pi *n like(outFromPos);
    inString  char(1024) const;
    inFromPos int(5)     const;
  end-pi;

    dcl-s outFromPos like(inFromPos);

    for outFromPos = inFromPos to %len(inString);
      if %subst(inString : outFromPos : 1) <> *blank;
        leave;
      endif;
    endfor;

    return outFromPos;

end-proc;


// -----------------------------------------------------------------------------
// Name ...... : get_FileNameFromString
// Description : Gets a filename from a string delimeted by blanks
// -----------------------------------------------------------------------------
dcl-proc get_FileNameFromString;

dcl-pi *n like(outFileName);
  inString  char(1024) Const;
  inFromPos int(5)     Const;
end-pi;

  dcl-s  outFileName  char(256);
  dcl-s  locBlanksPos int(5);
  dcl-s  locLength    int(5);

  clear outFileName;

  locBlanksPos = %scan(' ' : inString : inFromPos);

  if locBlanksPos = *zero;
    locBlanksPos = %len(inString) + 1;
  endif;

  locLength = locBlanksPos - inFromPos;
  if locLength > 0;
    outFileName = %subst(inString : inFromPos : locLength);
  endif;

  return outFileName;

end-proc;


// -----------------------------------------------------------------------------
// Name ...... : prep_Password_SFTP
// Description : Prepare the Password for SFTP
// -----------------------------------------------------------------------------
dcl-proc prep_Password_SFTP;

  dcl-pi *n ind;
    inPassword  like(T_FTP_Options.Password) const;
  end-pi;

    // Set the Password in the temp Table
    exec sql
      INSERT INTO SESSION.XYZ269 (Script)
        VALUES('#!/bin/sh'),
              ('printf ' CONCAT TRIM(:inPassword));

    if sqlcode <> 0;
      return cFalse;
    endif;

    // Place the Password file on the IFS
    Command = 'CPYTOIMPF FROMFILE(QTEMP/XYZ269) TOSTMF(' + cQuote + %trim(gblTempDir) + 'hm.sh' +
                cQuote + ') MBROPT(*REPLACE) STMFCCSID(1208) ' +
              'RCDDLM(*LF) STRDLM(*NONE) STRESCCHR(*NONE) RMVBLANK(*BOTH)';
    exec_Command(Command);

    // Set the Password
    Command = 'QSH CMD(' + cQuote + %trim(gblTempDir) + 'hm.sh' + cQuote + ')';
    exec_Command(Command);

    // Clear the temp table from the prep password scripts
    clear_FTPcmdFile();

    return cTrue;

end-proc;


// -----------------------------------------------------------------------------
// Name ...... : delete_TempTable_SFTP
// Description : Delete the Temp Table used by SFTP
// -----------------------------------------------------------------------------
dcl-proc delete_TempTable_SFTP;

  // Delete the Temp Table
  exec sql DROP TABLE SESSION.XYZ269;

  return;

end-proc;


// -----------------------------------------------------------------------------
// Name ...... : delete_TempDir_SFTP
// Description : Delete the Temp Directory used by SFTP
// -----------------------------------------------------------------------------
dcl-proc delete_TempDir_SFTP;

  if gblSFTP;

    // Remove SFTP Temp directory if not Debug mode
    if gblLog <> 'D';
      Command = 'RMVDIR DIR(' + cQuote + %trim(gblTempDir) + cQuote + ') SUBTREE(*ALL)';
      exec_Command(Command);
    endif;

    // Remove created spoolfiles if Password is used
    if gblPasswordUsed;
      Command = 'DLTSPLF FILE(QPRINT) JOB(' + %char(%editc(pgm_stat.jobno : 'X')) +
                '/' + %trim(pgm_stat.user) + '/' + %trim(pgm_stat.jobname) + ') ' +
                'SPLNBR(*LAST)';
      exec_Command(Command);
    endif;
  endif;

  return;

end-proc;


// -----------------------------------------------------------------------------
// Sub Procedure...: exec_Command
// Description.....: Execute Command
// -----------------------------------------------------------------------------
dcl-proc exec_Command;

  dcl-pi *n;
    inCommand   like(Command) const;
  end-pi;

    dcl-pr QCMDEXC extpgm;
      *n  char(256) options(*varsize) const;
      *n  packed(15:5) const;
    end-pr;

    QCMDEXC(inCommand:%len(%trimr(inCommand)));

    return;

end-proc;

