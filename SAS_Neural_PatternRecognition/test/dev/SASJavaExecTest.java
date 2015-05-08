package dev;

import org.junit.Test;

import java.util.Date;

import static org.junit.Assert.assertEquals;

/**
 * @author <a href="mailto:Tim.Haley@sas.com">Tim Haley, SAS Institute</a>
 */
public class SASJavaExecTest {

    /**
     * Note that this test will successfully execute both commands, the second one first.
     */
    @Test
    public void testExecuteMultipleInstancesSuccessfully()  {

        final SASJavaExec javaExec1 = new SASJavaExec("C:\\Windows\\System32\\cmd.exe", "/C echo Goodbye World");
        final SASJavaExec javaExec2 = new SASJavaExec("C:\\Windows\\System32\\cmd.exe", "/C echo Hello World");
        javaExec2.executeProcess();
        javaExec1.executeProcess();

    }

    @Test
    public void testExecuteProcess() {

        SASJavaExec jExec = new SASJavaExec("C:\\Windows\\System32\\cmd.exe", "/C echo Hello World");

        assertEquals(0, jExec.executeProcess());

    }

    @Test
    public void testExecuteProcessWithQuotesInScript() {

        SASJavaExec jExec = new SASJavaExec("C:\\Windows\\System32\\cmd.exe", "/C \'echo \"Hello World\"\'");

        assertEquals(0, jExec.executeProcess());

    }

    @Test
    public void testExecuteProcessWithQuotesInCmd() {

        SASJavaExec jExec = new SASJavaExec("\"C:\\Program Files\\Java\\jdk1.7.0_67\\bin\\java.exe\"", "-version");

        assertEquals(0, jExec.executeProcess(0.1));

    }

    @Test
    public void testExecuteProcessInDir() {

        // Set up the command to echo a string containing the current date into a text file in the working directory
        // and then print out the contents of that file
        SASJavaExec jExec = new SASJavaExec("C:\\Windows\\System32\\cmd.exe", "", "echo last run on "  + new Date() + " > test.txt\n type test.txt");

        // Set the working directory
        final String workingDirectory = "c:\\temp\\SASJavaExecTest\\";
        jExec.setWorkingDirectory(workingDirectory);

        // Execute the command
        assertEquals(0, jExec.executeProcess());

        //Verify that the working directory is as specified.
        assertEquals(workingDirectory, jExec.getWorkingDirectory());

    }

    @Test
    public void testExecuteProcessInvalidDir() {

        SASJavaExec jExec = new SASJavaExec("C:\\Windows\\System32\\cmd.exe", "", "echo testExecuteProcessInvalidDir >> test.txt");
        // For this to succeed, the a drive must not be mapped to any disk location.
        final String workingDirectory = "a:\\temp\\SASJavaExecTest\\";
        jExec.setWorkingDirectory(workingDirectory);

        assertEquals(-3, jExec.executeProcess());

    }

    @Test
    public void testRunExec() throws Exception {
        SASJavaExec jExec = new SASJavaExec("C:\\Windows\\System32\\cmd.exe", "/C echo Hello World");

        assertEquals(0, jExec.executeProcess(0.1));

    }

    @Test
    public void testExecuteProcessBadCmd() {

        SASJavaExec jExec = new SASJavaExec("C:\\Windows\\System32\\foo.bar", "/C");

        assertEquals(-1, jExec.executeProcess());

    }

    @Test
    public void testRunExecBadCmd() {
        SASJavaExec jExec = new SASJavaExec("C:\\Windows\\System32\\foo.bar", "/C");

        assertEquals(-1, jExec.executeProcess(0.1));

    }

    @Test
    public void testRunExecProcNon0Return() {
        SASJavaExec jExec = new SASJavaExec("C:\\Windows\\System32\\cmd.exe", "/C ls");

        assertEquals(1, jExec.executeProcess(0.1));

    }

    @Test
    public void tesExecuteProcessNon0Return() {
        SASJavaExec jExec = new SASJavaExec("C:\\Windows\\System32\\cmd.exe", "/C ls");

        assertEquals(1, jExec.executeProcess());

    }

    @Test
    public void testExecuteProcessWithInputText() {

        SASJavaExec jExec = new SASJavaExec("C:\\Windows\\System32\\cmd.exe", "", "echo hello world");

        assertEquals(0, jExec.executeProcess());

    }

    @Test
    public void testRunExecWithInputText() {
        SASJavaExec jExec = new SASJavaExec("C:\\Windows\\System32\\cmd.exe", "", "echo hello world");

        assertEquals(0, jExec.executeProcess(0.1));

    }
    @Test
    public void testExecuteProcessWithBadInputText() {

        SASJavaExec jExec = new SASJavaExec("C:\\Windows\\System32\\cmd.exe", "/C", "asdf hello world");

        assertEquals(0, jExec.executeProcess());

    }

    @Test
    public void testRunExecWithBadInputText() {
        SASJavaExec jExec = new SASJavaExec("C:\\Windows\\System32\\cmd.exe", "/C", "asdf hello world");

        assertEquals(0, jExec.executeProcess(0.1));

    }

    @Test
    public void testRunExecWithNonZeroReturn() {
        SASJavaExec jExec = new SASJavaExec("C:\\Windows\\System32\\cmd.exe", "/C exit 1234");

        assertEquals(1234, jExec.executeProcess(0.1));

    }

    @Test
    public void testRunExecTimeout() {
        SASJavaExec jExec = new SASJavaExec("C:\\Windows\\System32\\cmd.exe", "/C sleep 2000");

        assertEquals(-5, jExec.executeProcess(0.05));

    }
}