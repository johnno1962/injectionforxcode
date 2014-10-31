package com.injectionforxcode;

import com.intellij.openapi.actionSystem.AnAction;
import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.openapi.actionSystem.PlatformDataKeys;
import com.intellij.openapi.fileEditor.FileDocumentManager;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.openapi.ui.Messages;
import com.intellij.util.ui.UIUtil;

import java.util.regex.Pattern;
import java.util.Enumeration;
import java.net.*;
import java.io.*;

/**
 * Copyright (c) 2013 John Holdsworth. All rights reserved.
 *
 * Created with IntelliJ IDEA.
 * Date: 24/02/2013
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * If you want to "support the cause", consider a paypal donation to:
 *
 * injectionforxcode@johnholdsworth.com
 *
 */

public class InjectionAction extends AnAction {

    static InjectionAction plugin;

    {
        startServer(INJECTION_PORT);
        plugin = this;
    }

    public void actionPerformed(AnActionEvent event) {
        runScript("injectSource.pl", event);
    }

    static public class PatchAction extends AnAction {
        public void actionPerformed(AnActionEvent event) {
            plugin.runScript("patchProject.pl", event);
        }
    }

    static public class UnpatchAction  extends AnAction {
        public void actionPerformed(AnActionEvent event) {
            plugin.runScript("revertProject.pl", event);
        }
    }

    static public class BundleAction  extends AnAction {
        public void actionPerformed(AnActionEvent event) {
            plugin.runScript("openBundle.pl", event);
        }
    }

    static int alert( final String msg ) {
        UIUtil.invokeAndWaitIfNeeded(new Runnable() {
            public void run() {
                Messages.showMessageDialog(msg, "Injection Plugin", Messages.getInformationIcon());
            }
        } );
        return 0;
    }

    static void error( String where, Throwable e ) {
        alert(where + ": " + e + " " + e.getMessage());
        throw new RuntimeException( "Injection Plugin error", e );
    }

    static short INJECTION_PORT = 31444;
    static int INJECTION_MAGIC = -INJECTION_PORT*INJECTION_PORT;
    static int INJECTION_MKDIR = -1;
    static String CHARSET = "UTF-8";

    void startServer(int portNumber) {
        try {
            final ServerSocket serverSocket = new ServerSocket();
            serverSocket.setReuseAddress(true);
            serverSocket.bind(new InetSocketAddress(portNumber),5);

            new Thread( new Runnable() {
                public void run() {
                    while ( true )
                        try {
                            serviceClientApp(serverSocket.accept());
                        }
                    catch ( Throwable e ) {
                        error( "Error on accept", e );
                    }
                }
            } ).start();
        }
        catch ( IOException e ) {
            error("Unable to bind Server Socket", e );
        }
    }

    String mainFilePath = "", executablePath = "", arch = "";
    volatile OutputStream clientOutput;

    void serviceClientApp(final Socket socket) throws Throwable {

        socket.setTcpNoDelay(true);

        final InputStream clientInput = socket.getInputStream();
        clientOutput = socket.getOutputStream();
        patchNumber = 1;

        mainFilePath = readPath( clientInput, false );

        byte ok[] = new byte[] {1,0,0,0};
        clientOutput.write( ok );

        executablePath = readPath( clientInput, true );

        new Thread( new Runnable() {
            public void run() {
                try {
                    while ( true ) {
                        int bundleLoaded = readInt( clientInput );
                    }
                }
                catch ( IOException e ) {
                }
                finally {
                    try {
                        socket.close();
                    }
                    catch ( IOException e ) {
                    }
                    clientOutput = null;
                }
            }
        } ).start();
    }

    static String resourcesPath = System.getProperty( "user.home" )+"/Library/Application Support/Developer/Shared/Xcode/Plug-ins/InjectionPlugin.xcplugin/Contents/Resources/";
    static String unlockCommand = "chmod +w \"%s\"";

    int patchNumber = 0, INJECTION_NOTSILENT = 1<<2, INJECTION_APPCODE = 1<<4, flags = INJECTION_NOTSILENT | INJECTION_APPCODE;

    static String serverAddresses() throws SocketException {
        String ipaddrs = "127.0.0.1";
        NetworkInterface ni = NetworkInterface.getByName("en0");
        if ( ni != null )
            for ( Enumeration<InetAddress> e = ni.getInetAddresses() ; e.hasMoreElements() ; )
                ipaddrs += "  "+e.nextElement().getHostAddress();
        return ipaddrs; // should return space separated ip addresses serverSocket is listening on
    }

    int runScript( String script, AnActionEvent event ) {
        try {
            if ( !new File(resourcesPath+"appcode.txt").exists() )
                return alert( "Version 3.2 of the Xcode version of the Injection plugin"
                             +" from http://injectionforxcode.com must also be installed." );

            Project project = event.getData(PlatformDataKeys.PROJECT);
            VirtualFile vf = event.getData(PlatformDataKeys.VIRTUAL_FILE);
            if ( vf == null )
                return 0;

            String selectedFile = vf.getCanonicalPath();
            if ( script == "patchProject.pl" )
                selectedFile = ""+INJECTION_PORT+" // AppCode";

            else if ( script == "injectSource.pl" && clientOutput == null )
                return alert( "Application not running/connected.");

            else if ( selectedFile == null || !Pattern.matches( ".+\\.(m|mm|swift)$", selectedFile ) )
                return alert( "Select text in an implementation file to inject..." );

            FileDocumentManager.getInstance().saveAllDocuments();

            processScriptOutput(script, new String[]{resourcesPath + script, resourcesPath,
                project.getProjectFilePath(), mainFilePath, executablePath, arch, "" + ++patchNumber,
                "" + flags, unlockCommand, serverAddresses(), selectedFile}, event);
        }
        catch ( Throwable e ) {
            error( "Run script error", e );
        }

        return 0;
    }

    void processScriptOutput(final String script, String command[], final AnActionEvent event) throws IOException {

        final Process process = Runtime.getRuntime().exec( command, null, null);
        final BufferedReader stdout = new BufferedReader( new InputStreamReader( process.getInputStream(), CHARSET ) );

        new Thread( new Runnable() {
            public void run() {
                try {
                    String line;
                    while ( (line = stdout.readLine()) != null )
                        processLine(line);
                }
                catch ( IOException e ) {
                    error( "Script i/o error", e );
                }

                try {
                    stdout.close();
                    if ( process.waitFor() != 0 )
                        if ( script == "injectSource.pl" )
                            UIUtil.invokeAndWaitIfNeeded(new Runnable() {
                                public void run() {
                                    if ( Messages.showYesNoDialog("Build Failed -- You may want to open "+
                                                                  "Injection's bundle project to resolve the problem.", "Injection Plugin",
                                                                  "OK", "Open Bundle Project", Messages.getInformationIcon()) == 1 )
                                        runScript( "openBundle.pl", event );
                                }
                            } );
                        else
                            alert(script + " returned failure.");
                }
                catch ( Throwable e ) {
                    error( "Wait problem", e );
                }
            }
        } ).start();
    }

    static Pattern removeRTF = Pattern.compile( "\\{\\\\.*?\\}(?!\\{)|\\\\(b|(i|cb)\\d)\\s*" );

    String filein;

    void processLine(String line) throws IOException {
        char char0 = line.length() > 0 ? line.charAt(0) : 0;
        line = removeRTF.matcher(line).replaceAll("");

        if ( char0 == '?' || clientOutput == null ) {
            alert(line);
            return;
        }

        if ( char0 == '<' ) {
            filein = line.substring(1);
            return;
        }

        if ( char0 == '!' ) {
            line = line.substring(1); // actual command for client app

            // copies file/dir to client for on-device injection
            if ( line.charAt(0) ==  '>' && filein != null ) {
                File from = new File( filein );
                if ( from.isDirectory() )
                    writeCommand( clientOutput, line, INJECTION_MKDIR );
                else {
                    int size = (int)from.length();
                    byte buffer[] = new byte[size];

                    FileInputStream is = new FileInputStream( filein );
                    is.read(buffer);
                    is.close();

                    writeCommand(clientOutput, line, size);
                    clientOutput.write(buffer);
                    filein = null;
                }
                return;
            }
        }
        else
            line = "!Injection: "+line; // otherwise output sent to client to echo to console

        int MAX_LINE = 500;
        if ( line.length() > MAX_LINE )
            line = line.substring(0,MAX_LINE)+" ...";

        writeCommand( clientOutput, line, INJECTION_MAGIC );
    }

    static int unsign( byte  b ) {
        return (int)b & 0xff;
    }

    static int readInt( InputStream s ) throws IOException {
        byte bytes[] = new byte[4];
        if ( s.read(bytes) != bytes.length )
            throw new IOException( "readInt() EOF" );
        return unsign(bytes[0]) + (unsign(bytes[1])<<8) + (unsign(bytes[2])<<16) + (unsign(bytes[3])<<24);
    }

    String readString( InputStream s, int pathLength ) throws IOException {
        byte buffer[] = new byte[pathLength];
        if ( s.read(buffer) != pathLength )
            alert("Bad path read");
        return new String( buffer, 0, pathLength-1, CHARSET );
    }

    String readPath( InputStream s, boolean setArch ) throws IOException {
        int pathLength = readInt( s ), dataLength = readInt( s );
        if ( pathLength < 0 )
            alert("-ve path len: " + pathLength);

        String path = readString( s, pathLength );
        if ( setArch )
            arch = readString( s, dataLength );
        else if ( dataLength != INJECTION_MAGIC )
            alert("Bad connection magic");
        return path;
    }

    static void writeCommand( OutputStream s, String path, int dataLength ) throws IOException {
        byte bytes[] = path.getBytes( CHARSET ), buffer[] = new byte[bytes.length+1];
        System.arraycopy( bytes, 0, buffer, 0, bytes.length );
        writeHeader( s, bytes.length+1, dataLength );
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
