/**
 * ***************************************************************************
 * Copyright (c) 2015 by SAS Institute Inc., Cary, NC 27513 USA
 * <p/>
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * <p/>
 * http://www.apache.org/licenses/LICENSE-2.0
 * <p/>
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * <p/>
 * ****************************************************************************
 */

package dev;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.text.MessageFormat;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.*;
import java.util.logging.Logger;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static java.util.logging.Level.SEVERE;

/**
 * This class can be instantiated from the Base SAS Java Object and used to
 * asynchronously fork a new process.<br/>
 * <br/>
 * Example:<br/>
 * First instantiate the object like this:<br/>
 * declare javaobj j("dev.SASJavaExec", "&PYTHON_EXEC_COMMAND", python_call);<br/>
 * <br/>
 * Optionally, set the working directory like this:<br/>
 * j.callVoidMethod("setWorkingDirectory", "c:\\temp\\SASJavaExec\\");<br/>
 * <br/>
 * Then call the executeProcess method like this:<br/>
 * j.callIntMethod("executeProcess", rtn_val);<br/>
 * <br/>
 * Or the executeProcess method, specifying a timeout in minutes, like this:<br/>
 * j.callIntMethod("executeProcess", 6, rtn_val);<br/>
 * <br/>
 *
 * @author <a href="mailto:patrick.hall@sas.com">Patrick Hall, SAS Institute</a>
 * @author <a href="mailto:radhikha.myneni@sas.com">Radhikha Myneni, SAS Institute</a>
 * @author <a href="mailto:ruiwen.zhang@sas.com">Ruiwen Zhang, SAS Institute</a>
 * @author <a href="mailto:tim.haley@sas.com">Tim Haley, SAS Institute</a>
 * @version 0.2
 * @since 2015-04-01
 */
public class SASJavaExec {

    private static final Logger logger = Logger.getLogger(SASJavaExec.class.getName());

    /**
     * Timeout default in minutes for executeProcess method.
     */
    private final static long DEFAULT_TIMEOUT = 1000L;
    /**
     * Path to executable command.
     */
    private final String execCommand;
    /**
     * Path to Class or script to execute.
     */
    private final String script;
    /**
     * Optional input string to provide on the standard input of the executed process.
     */
    private final String inputString;

    /**
     * Optional directory in which to execute
     */
    private String workingDirectory;

    public String getWorkingDirectory() {
        return workingDirectory;
    }

    public void setWorkingDirectory(String workingDirectory) {
        this.workingDirectory = workingDirectory;
    }

    /**
     * Constructs a SASJavaExec object with NO command line arguments to STDIN.
     *
     * @param execCommand Path to executable, i.e. C:\Anaconda\python.exe
     * @param script      Path to Class or script to execute, including any command line arguments,
     *                    i.e. C:\Path\to\digitsdata_svm.py
     */
    public SASJavaExec(String execCommand, String script) {
        this(execCommand, script, null);
    }

    /**
     * Constructs a SASJavaExec object with command line arguments to STDIN.
     *
     * @param execCommand Path to executable, i.e. C:\Program Files\R\R-3.1.2\bin\x64\Rscript.exe
     * @param script      Path to Class or script to execute, including any command line arguments,
     *                    i.e. &WORK_DIR.\digitsdata_svm.R &WORK_DIR
     * @param inputString Optional input values for STDIN, i.e. interactive input to command.
     */
    public SASJavaExec(String execCommand, String script, String inputString) {
        this.execCommand = execCommand.trim();
        this.script = script.trim();
        this.inputString = inputString;
    }

    /**
     * Executes the process specified by execCommand, className, and optionally,
     * inValuesString.
     *
     * @return the exit code from the process, or <br/>
     * -1 if the process failed to start <br/>
     * -2 if interrupted and the process was killed <br/>
     * -3 if the working directory could not be created. <br/>
     * -4 if a file with the working directory name exists but is not a directory. <br/>
     */
    public int executeProcess() {

        // passing arguments with spaces in them to ProcessBuilder causes extraneous quotes so
        // we split all command strings by spaces and pass the array in the original order.
        final List<String> processStrings = tokenizeString(execCommand);
        processStrings.addAll(tokenizeString(script));

        logger.info(MessageFormat.format("Executing {0} ...", processStrings));

        final ProcessBuilder processBuilder = new ProcessBuilder(processStrings);

        if (workingDirectory != null) {
            final Path dir = Paths.get(workingDirectory);
            if (Files.notExists(dir)) {
                try {
                    Files.createDirectories(dir);
                } catch (IOException e) {
                    logger.warning("Could not create working directory: " + workingDirectory);
                    return -3;
                }
            } else if (!Files.isDirectory(dir)) {
                logger.warning(workingDirectory + " already exists but is not a directory.");
                return -4;
            }
            final File directory = dir.toFile();

            processBuilder.directory(directory);
        }

        // Redirect STDERR to STDOUT.
        processBuilder.redirectErrorStream(true);

        Integer exitValue;

        try {
            logger.info("Starting external process ...");
            final Process process = processBuilder.start();

            sendInputStringToProcess(process);

            // This handles both STDOUT and STDERR and does not return until the process closes
            // both streams, typically when it terminates.
            handleProcessOutput(process);

            // Wait for the process to return an exit value
            try {
                exitValue = process.waitFor();
            } catch (InterruptedException e) {
                logger.warning("Interrupted while waiting, killing external process ...");
                process.destroy();
                exitValue = -2;
            }
            logger.info("External process exit value " + exitValue + ".");
        } catch (IOException e) {
            logger.log(SEVERE, "Failed to start external Process: ", e.getCause());
            exitValue = -1;
        }
        return exitValue;
    }

    /**
     * Executes the process with a time limit of timeoutMin.
     *
     * @param timeoutMin the maximum number of minutes to wait for the process to complete.
     *                   May be fractional; eg: 0.1 is 6 seconds.
     *                   0.0 or less will result in the default timeout of 1000 minutes.
     *
     * @return the exit code from the process, or
     * -1 if the process failed to start
     * -2 if interrupted and the process was killed
     * -3 if the working directory could not be created.
     * -4 if a file with the working directory name exists but is not a directory.
     * -5 if the process timed out
     */
    public int executeProcess(double timeoutMin) {

        int exitValue;

        final long timeoutInSeconds = Math.round(((timeoutMin > 0) ? timeoutMin : DEFAULT_TIMEOUT) * 60);

        logger.info("Using Single Thread Executor.");

        final ExecutorService executor = Executors.newSingleThreadExecutor();
        final Future<Integer> future = executor.submit(new Callable<Integer>() {
            public Integer call() throws Exception {
                return executeProcess();
            }
        });

        try {
            // Wait for and return the result of the executed process.
            exitValue = future.get(timeoutInSeconds, TimeUnit.SECONDS); //timeout is in timeoutMin minutes
            logger.info("Process completed with exit value: " + exitValue);
        } catch (TimeoutException e) {
            logger.log(SEVERE, "Process timed out after " + timeoutMin + " minutes.");
            exitValue = -5;
        } catch (ExecutionException e) {
            logger.log(SEVERE, "Process threw an exception.", e.getCause());
            exitValue = -6;
        } catch (InterruptedException e) {
            logger.warning("Interrupted while waiting for process to complete.");
            future.cancel(true);
            exitValue = -2;
        }
        executor.shutdownNow();
        return exitValue;
    }

    /**
     * Parse the string into separate tokens, which are separated by spaces in the input.
     * Handles strings containing matched pairs of single or double quotes.
     * Anything inside of a matched pair of quotes is considered a single token, excluding the quotation marks.
     * Single and double quotes can be mixed to support including either single or double quotes in the token.
     * Ex: <em>this 'is "an example"' of mixing quotes</em> will be parsed into [this, is "an example", of, mixing, quotes]
     *
     * @param input the string to parse.
     *
     * @return the list of tokens found in the string.
     */
    private List<String> tokenizeString(String input) {
        List<String> matchList = new ArrayList<>();
        Pattern regex = Pattern.compile("[^\\s\"']+|\"([^\"]*)\"|'([^']*)'");
        Matcher regexMatcher = regex.matcher(input);
        while (regexMatcher.find()) {
            if (regexMatcher.group(1) != null) {
                // Add double-quoted string without the quotes
                matchList.add(regexMatcher.group(1));
            } else if (regexMatcher.group(2) != null) {
                // Add single-quoted string without the quotes
                matchList.add(regexMatcher.group(2));
            } else {
                // Add unquoted word
                matchList.add(regexMatcher.group());
            }
        }
        return matchList;
    }

    /**
     * If an input string was specified, stream it to the process standard input.
     *
     * @param process the process that is expecting the string.
     */
    private void sendInputStringToProcess(Process process) {

        if (inputString != null) {
            // Try with resources will automatically close the resources, no finally block is needed.
            try (PrintStream ps = new PrintStream(process.getOutputStream())) {
                ps.print(inputString);
                ps.print('\n');
            }
        }
    }

    /**
     * Read process output line by line and write it to the log.
     *
     * @param process for which to handle the output.
     */
    private void handleProcessOutput(Process process) {

        // Try with resources will automatically close the resources, no finally block is needed.
        try (BufferedReader br = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
            String line;
            while ((line = br.readLine()) != null) {
                logger.info("PROCESS OUTPUT >>>    " + line);
            }
        } catch (IOException e) {
            logger.log(SEVERE, "Failed to read output from external Process: ", e.getCause());
        }
    }
}
