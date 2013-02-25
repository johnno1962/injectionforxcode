package com.injectionforxcode;

import com.intellij.openapi.actionSystem.AnAction;
import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.openapi.actionSystem.PlatformDataKeys;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.openapi.ui.Messages;
import com.intellij.util.ui.UIUtil;

import java.net.ServerSocket;
import java.net.Socket;
import java.io.*;

/**
 * Created with IntelliJ IDEA.
 * User: johnholdsworth
 * Date: 24/02/2013
 * Time: 11:36
 * To change this template use File | Settings | File Templates.
 */
public class InjectionAction extends AnAction {

    public void actionPerformed(AnActionEvent event) {
        runScript("injectSource.pl", event);
    }

    static public class PatchAction extends AnAction {
        public void actionPerformed(AnActionEvent event) {
            runScript("patchProject.pl", event);
        }
    }

    static public class UnpatchAction  extends AnAction {
        public void actionPerformed(AnActionEvent event) {
            runScript("revertProject.pl", event);
        }
    }

    static public class BundleAction  extends AnAction {
        public void actionPerformed(AnActionEvent event) {
            runScript("openBundle.pl", event);
        }
    }

    static String CHARSET = "UTF-8";
    static short INJECTION_PORT = 31444;
    static int INJECTION_MAGIC = -INJECTION_PORT*INJECTION_PORT;

    static String mainFilePath = "", executablePath = "";

    static ServerSocket serverSocket;
    static OutputStream clientOutput;

    static void error( final String msg ) {
        UIUtil.invokeAndWaitIfNeeded(new Runnable() {
            public void run() {
                Messages.showMessageDialog((Project)null, msg, "Injection Plugin", Messages.getInformationIcon());
            }
        } );
    }

    static {
        try {
            serverSocket = new ServerSocket( INJECTION_PORT );
            new Thread( new Runnable() {
                public void run() {
                    while ( true ) {
                        try {
                            serviceConnection();
                        }
                        catch ( Throwable e ) {
                            error( "Error on accept: "+e+" "+e.getMessage() );
                        }
                    }
                }
            } ).start();
        }
        catch ( IOException e ) {
            error("Unable to setup Server Socket: "+e+" "+e.getMessage());
        }
    }

    static void serviceConnection() throws  Throwable {

        final Socket socket = serverSocket.accept();
        socket.setTcpNoDelay(true);

        final InputStream clientInput = socket.getInputStream();
        clientOutput = socket.getOutputStream();
        patchNumber = 1;

        mainFilePath = readPath( clientInput );

        byte bytes[] = new byte[] {1,0,0,0};
        clientOutput.write( bytes );

        executablePath = readPath( clientInput );
        //writePath( clientOutput, "!Connection from: "+executablePath);

        new Thread( new Runnable() {
            public void run() {
                try {
                    while ( true ) {
                        int bundleLoaded = readInt( clientInput );
                    }
                }
                catch ( IOException e ) {
                    try {
                        socket.close();
                    }
                    catch ( IOException e1 ) {
                    }
                    finally {
                        clientOutput = null;
                    }
                }
            }
        } ).start();
    }

    static String resourcesPath = System.getProperty( "user.home" )+"/Library/Application Support/Developer/Shared/Xcode/Plug-ins/InjectionPlugin.xcplugin/Contents/Resources/";
    static String unlockCommand = "chmod +w \"%s\"";
    static int patchNumber = 0, flags = 1<<2 | 1<<4;

    static String serverAddresses() {
        // should return space separated ip addresses serverSocket is listening on
        return "127.0.0.1";
    }

    static void runScript( final String script, final AnActionEvent event ) {
        try {
            if ( !new File(resourcesPath+"appcode.txt").exists() ) {
                error( "Version 3.2 of the Xcode version of the Injection plugin must be installed." );
                return;
            }

            Project project = event.getData(PlatformDataKeys.PROJECT);
            VirtualFile vf = event.getData(PlatformDataKeys.VIRTUAL_FILE);
            if ( vf == null )
                return;

            String selectedFile = vf.getCanonicalPath();
            if ( script == "patchProject.pl" )
                selectedFile = ""+INJECTION_PORT;
            else if ( script == "injectSource.pl" && clientOutput == null ) {
                error( "Application not running/connected.");
                return;
            }
            else if ( selectedFile == null || selectedFile.charAt( selectedFile.length()-1 ) != 'm' ) {
                error( "Select text in an implmentation file to inject..." );
                return;
            }

            String contents = event.getData(PlatformDataKeys.FILE_TEXT);
            if ( contents != null )
                new FileOutputStream( selectedFile ).write( contents.getBytes( CHARSET ) );

            final Process proc = Runtime.getRuntime().exec(new String[]{resourcesPath + script, resourcesPath,
                    project.getProjectFilePath(), mainFilePath, executablePath, "" + ++patchNumber,
                    "" + flags, unlockCommand, serverAddresses(), selectedFile}, null, null);
            final BufferedReader stdout = new BufferedReader( new InputStreamReader( proc.getInputStream(), CHARSET ) );

            new Thread( new Runnable() {
                public void run() {
                    try {
                        String line;
                        while ( (line = stdout.readLine()) != null ) {
                            char char0 = line.length() > 0 ? line.charAt(0) : 0;

                            if ( char0 == '?' || clientOutput == null ) {
                                error( line );
                                continue;
                            }

                            if ( char0 == '!' )
                                line = line.substring(1);
                            else
                                line = "!Injection: "+line.replaceAll( "\\{\\\\.*?\\}(?!\\{)|\\\\(b|(i|cb)\\d)","");

                            int MAX_LINE = 500;
                            if ( line.length() > MAX_LINE )
                                line = line.substring(0,MAX_LINE)+" ...";

                            writeCommand( clientOutput, line );
                        }
                    }
                    catch ( IOException e ) {
                        error( "Script i/o error: "+e.getMessage() );
                    }
                    try {
                        stdout.close();
                        if ( proc.waitFor() != 0 )
                            if ( script == "injectSource.pl" )
                                UIUtil.invokeAndWaitIfNeeded(new Runnable() {
                                    public void run() {
                                        if ( Messages.showYesNoDialog((Project)null, "Build Failed -- You may want to open "+
                                                "Injection's bundle project to resolve the problem.", "Injection Plugin",
                                                "OK", "Open Bundle Project", Messages.getInformationIcon()) == 1 )
                                            runScript( "openBundle.pl", event );
                                    }
                                } );
                            else
                                error( script+" returned failure." );
                    }
                    catch ( Throwable e ) {
                        error( "Wait problem: "+e+" "+e.getMessage() );
                    }
                }
            } ).start();
        }
        catch ( Throwable e ) {
            error( "Run script "+e+": "+e.getMessage() );
        }
    }

    static int unsign( byte  b ) {
        return (int)b&0xff;
    }

    static int readInt( InputStream s ) throws IOException {
        byte bytes[] = new byte[4];
        if ( s.read(bytes) != bytes.length )
            throw new IOException( "readInt() EOF" );
        return unsign(bytes[0])+(unsign(bytes[1])<<8)+(unsign(bytes[2])<<16)+(unsign(bytes[3])<<24);
    }

    static String readPath( InputStream s ) throws IOException {
        int pathLength = readInt( s );
        if ( readInt( s ) != INJECTION_MAGIC )
            error( "Bad connection magic" );
        if ( pathLength < 0 )
            error( "-ve path len: "+pathLength );

        byte buffer[] = new byte[pathLength];
        if ( s.read(buffer) != pathLength )
            error( "Bad path read" );
        return new String( buffer, 0, pathLength-1, CHARSET );
    }

    static void writeCommand( OutputStream s, String path ) throws IOException {
        byte bytes[] = path.getBytes( CHARSET ), buffer[] = new byte[bytes.length+1];
        System.arraycopy( bytes, 0, buffer, 0, bytes.length );
        writeHeader( s, bytes.length+1, INJECTION_MAGIC );
        s.write( buffer );
    }

    static void writeHeader( OutputStream s, int i1, int i2 ) throws IOException {
        byte bytes[] = new byte[8];
        bytes[0] = (byte) (i1);
        bytes[1] = (byte) (i1 >> 8);
        bytes[2] = (byte) (i1 >> 16);
        bytes[3] = (byte) (i1 >> 24);
        bytes[4] = (byte) (i2);
        bytes[5] = (byte) (i2 >> 8);
        bytes[6] = (byte) (i2 >> 16);
        bytes[7] = (byte) (i2 >> 24);
        s.write( bytes );
    }

}
