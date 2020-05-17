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
package hu.bme.mit.gamma.codegenerator.java

import hu.bme.mit.gamma.codegenerator.java.util.Namings
import hu.bme.mit.gamma.statechart.model.interface_.EventDirection
import hu.bme.mit.gamma.statechart.model.interface_.Interface

import static extension hu.bme.mit.gamma.codegenerator.java.util.Namings.*

class PortInterfaceGenerator {
	
	protected final String PACKAGE_NAME
	//
	protected final extension EventDeclarationHandler gammaEventDeclarationHandler
	protected final extension NameGenerator nameGenerator
	
	new(String packageName, Trace trace) {
		this.PACKAGE_NAME = packageName
		this.gammaEventDeclarationHandler = new EventDeclarationHandler(trace)
		this.nameGenerator = new NameGenerator(this.PACKAGE_NAME)
	}
	
	def generatePortInterfaces(Interface anInterface) '''
		package «PACKAGE_NAME».«Namings.INTERFACE_PACKAGE_POSTFIX»;
		
		import «PACKAGE_NAME».*;
		import java.util.List;
		
		public interface «anInterface.implementationName» {
			
			interface Provided extends Listener.Required {
				
				«anInterface.generateIsRaisedInterfaceMethods(EventDirection.IN)»
				
				void registerListener(Listener.Provided listener);
				List<Listener.Provided> getRegisteredListeners();
			}
			
			interface Required extends Listener.Provided {
				
				«anInterface.generateIsRaisedInterfaceMethods(EventDirection.OUT)»
				
				void registerListener(Listener.Required listener);
				List<Listener.Required> getRegisteredListeners();
			}
			
			interface Listener {
				
				interface Provided «IF !anInterface.parents.empty»extends «FOR parent : anInterface.parents»«parent.implementationName».Listener.Provided«ENDFOR»«ENDIF» {
					«FOR event : anInterface.events.filter[it.direction != EventDirection.IN]»
						void raise«event.event.name.toFirstUpper»(«event.generateParameter»);
					«ENDFOR»							
				}
				
				interface Required «IF !anInterface.parents.empty»extends «FOR parent : anInterface.parents»«parent.implementationName».Listener.Required«ENDFOR»«ENDIF» {
					«FOR event : anInterface.events.filter[it.direction != EventDirection.OUT]»
						void raise«event.event.name.toFirstUpper»(«event.generateParameter»);
					«ENDFOR»  					
				}
				
			}
		}
	'''
	
	private def generateIsRaisedInterfaceMethods(Interface anInterface, EventDirection oppositeDirection) '''
	«««		Simple flag checks
		«FOR event : anInterface.events.filter[it.direction != oppositeDirection].map[it.event]»
			public boolean isRaised«event.name.toFirstUpper»();
	«««		ValueOf checks	
			«IF event.parameterDeclarations.size > 0»
				public «event.parameterDeclarations.eventParameterType» get«event.name.toFirstUpper»Value();
			«ENDIF»
		«ENDFOR»
	'''
}