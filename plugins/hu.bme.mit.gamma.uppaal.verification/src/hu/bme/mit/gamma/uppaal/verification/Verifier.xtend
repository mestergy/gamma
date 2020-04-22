/********************************************************************************
 * Copyright (c) 2018-2020 Contributors to the Gamma project
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * SPDX-License-Identifier: EPL-1.0
 ********************************************************************************/
package hu.bme.mit.gamma.uppaal.verification

import hu.bme.mit.gamma.trace.model.ExecutionTrace
import hu.bme.mit.gamma.uppaal.verification.result.ThreeStateBoolean
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.io.PrintWriter
import java.util.Scanner
import java.util.logging.Level
import java.util.logging.Logger
import org.eclipse.emf.ecore.resource.ResourceSet

class Verifier {
	
	volatile boolean isCancelled
	Process process
	ThreeStateBoolean result
	String output
	Logger logger = Logger.getLogger("GammaLogger")
	
	def ExecutionTrace verifyQuery(ResourceSet traceabilitySet, String parameters, File uppaalFile,
			String actualUppaalQuery, boolean log, boolean storeOutput) throws IOException  {
		var Scanner resultReader = null
		var Scanner traceReader = null
		var VerificationResultReader verificationResultReader = null
		try {
			// Writing the query to a temporary file
			val parentFolder = uppaalFile.parent
			val tempQueryfile = writeToFile(actualUppaalQuery, parentFolder, ".temporary_query.q")
			// Deleting the file on the exit of the JVM
			tempQueryfile.deleteOnExit
			// verifyta -t0 -T TestOneComponent.xml asd.q 
			val command = new StringBuilder
			command.append("verifyta " + parameters + " \"" + uppaalFile.toString + "\" \"" + tempQueryfile.canonicalPath + "\"")
			// Executing the command
			logger.log(Level.INFO, "Executing command: " + command.toString)
			process =  Runtime.getRuntime().exec(command.toString)
			val outputStream = process.inputStream
			val errorStream = process.errorStream
			// Reading the result of the command
			resultReader = new Scanner(outputStream)
			verificationResultReader = new VerificationResultReader(resultReader, log, storeOutput)
			new Thread(verificationResultReader).start
			traceReader = new Scanner(errorStream)
			if (isCancelled) {
				// If the process is killed, this is where it can be checked
				throw new NotBackannotatedException(ThreeStateBoolean.UNDEF)
			}
			if (!traceReader.hasNext()) {
				// No back annotation of empty lines
				throw new NotBackannotatedException(handleEmptyLines(actualUppaalQuery))
			}
			logger.log(Level.INFO, "Resource set content for string trace back-annotation: " + traceabilitySet)
			val backAnnotator = new StringTraceBackAnnotator(traceabilitySet, traceReader)
			val traceModel = backAnnotator.execute
			if (storeOutput) {
				output = verificationResultReader.output
			}
			result = actualUppaalQuery.handleEmptyLines.opposite
			return traceModel
		} catch (EmptyTraceException e) {
			result = handleEmptyLines(actualUppaalQuery)
			return null
		} catch (NotBackannotatedException e) {
			result = e.result
			return null
		} finally {
			resultReader.close();
			traceReader.close();
			verificationResultReader.cancel();
		}
	}
	
	def cancel() {
		isCancelled = true
		if (process !== null) {
			process.destroy();
			try {
				// Waiting for process to end
				process.waitFor();
			} catch (InterruptedException e) {}
		}
	}
	
	def getProcess() {
		return process
	}
	
	def getResult() {
		return result
	}
	
	def getOutput() {
		return output
	}
	
	/**
	 * Returns the correct verification answer when there is no generated trace by the UPPAAL.
	 */
	private def ThreeStateBoolean handleEmptyLines(String uppaalQuery) {
		if (uppaalQuery.startsWith("A[]") || uppaalQuery.startsWith("A<>")) {
			// In  thecase of A, empty trace means the requirement is met
			return ThreeStateBoolean.TRUE
		}
		// In the case of E, empty trace means the requirement is not met
		return ThreeStateBoolean.FALSE
	}
	
	private def File writeToFile(String string, String parentFolder, String fileName) throws FileNotFoundException {
		new File(parentFolder).mkdirs // Creating parent folder if needed
		val fileLocation = parentFolder + File.separator + fileName
		val file = new File(fileLocation)
		try (val writer = new PrintWriter(fileLocation)) {
			writer.print(string)
		}
		return file
	}
	
}