/********************************************************************************
 * Copyright (c) 2020-2021 Contributors to the Gamma project
 * 
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 * 
 * SPDX-License-Identifier: EPL-1.0
 ********************************************************************************/
package hu.bme.mit.gamma.scenario.statechart.generator

import hu.bme.mit.gamma.expression.model.Expression
import hu.bme.mit.gamma.scenario.model.AlternativeCombinedFragment
import hu.bme.mit.gamma.scenario.model.Delay
import hu.bme.mit.gamma.scenario.model.InteractionDefinition
import hu.bme.mit.gamma.scenario.model.InteractionDirection
import hu.bme.mit.gamma.scenario.model.LoopCombinedFragment
import hu.bme.mit.gamma.scenario.model.ModalInteractionSet
import hu.bme.mit.gamma.scenario.model.ModalityType
import hu.bme.mit.gamma.scenario.model.NegPermissiveAnnotation
import hu.bme.mit.gamma.scenario.model.NegStrictAnnotation
import hu.bme.mit.gamma.scenario.model.NegatedModalInteraction
import hu.bme.mit.gamma.scenario.model.NegatedWaitAnnotation
import hu.bme.mit.gamma.scenario.model.OptionalCombinedFragment
import hu.bme.mit.gamma.scenario.model.PermissiveAnnotation
import hu.bme.mit.gamma.scenario.model.ScenarioDefinition
import hu.bme.mit.gamma.scenario.model.Signal
import hu.bme.mit.gamma.scenario.model.StrictAnnotation
import hu.bme.mit.gamma.scenario.model.WaitAnnotation
import hu.bme.mit.gamma.scenario.model.derivedfeatures.ScenarioModelDerivedFeatures
import hu.bme.mit.gamma.statechart.contract.NotDefinedEventMode
import hu.bme.mit.gamma.statechart.interface_.Component
import hu.bme.mit.gamma.statechart.interface_.TimeUnit
import hu.bme.mit.gamma.statechart.interface_.Trigger
import hu.bme.mit.gamma.statechart.statechart.BinaryTrigger
import hu.bme.mit.gamma.statechart.statechart.BinaryType
import hu.bme.mit.gamma.statechart.statechart.ChoiceState
import hu.bme.mit.gamma.statechart.statechart.Region
import hu.bme.mit.gamma.statechart.statechart.State
import hu.bme.mit.gamma.statechart.statechart.StateNode
import hu.bme.mit.gamma.statechart.statechart.StatechartDefinition
import hu.bme.mit.gamma.statechart.statechart.Transition
import hu.bme.mit.gamma.statechart.statechart.TransitionPriority
import java.math.BigInteger
import java.util.HashMap
import java.util.List

import static extension hu.bme.mit.gamma.statechart.derivedfeatures.StatechartModelDerivedFeatures.*

enum StatechartGenerationMode {
	GENERATE_MERGE_STATE,
	GENERATE_ORIGINAL_STRUCTURE,
	GENERATE_ONLY_FORWARD,
	GENERATE_DUPLICATED_CHOICES
}

class TestGeneratorStatechartGenerator extends AbstractContractStatechartGeneration {

	var allowedGlobalWaitMax = 0
	var allowedGlobalWaitMin = 0
	var allowedGlobalWaitNegMax = 0
	var StateNode previousState = null
	var State hotViolation = null
	var State coldViolation = null
	var NotDefinedEventMode nonDeclaredMessageMode = NotDefinedEventMode.PERMISSIVE
	var NotDefinedEventMode nonDeclaredNegMessageMode = NotDefinedEventMode.STRICT
	val boolean coldViolationExisits
	val StatechartGenerationMode generationMode
	var Region firstRegion = null
	val replacedStateWithValue = new HashMap<StateNode, StateNode>()

	new(ScenarioDefinition scenario, Component component, StatechartGenerationMode mode,
		boolean dedicatedColdViolation) {
		this.component = component
		this.generationMode = mode
		this.scenario = scenario
		this.coldViolationExisits = dedicatedColdViolation
	}

	new(ScenarioDefinition scenario, Component component) {
		this(scenario, component, StatechartGenerationMode.GENERATE_ONLY_FORWARD, true)
	}

	def StatechartDefinition execute() {
		statechart = createStatechartDefinition
		for (annotation : scenario.annotation) {
			if (annotation instanceof WaitAnnotation) {
				allowedGlobalWaitMax = annotation.maximum.evaluateInteger
				allowedGlobalWaitMin = annotation.minimum.evaluateInteger
			} else if (annotation instanceof StrictAnnotation) {
				nonDeclaredMessageMode = NotDefinedEventMode.STRICT
			} else if (annotation instanceof PermissiveAnnotation) {
				nonDeclaredMessageMode = NotDefinedEventMode.PERMISSIVE
			} else if (annotation instanceof NegatedWaitAnnotation) {
				allowedGlobalWaitNegMax = annotation.maximum.evaluateInteger
			} else if (annotation instanceof NegStrictAnnotation) {
				nonDeclaredNegMessageMode = NotDefinedEventMode.STRICT
			} else if (annotation instanceof NegPermissiveAnnotation) {
				nonDeclaredNegMessageMode = NotDefinedEventMode.PERMISSIVE
			}
		}

		initializeStateChart(scenario.name)

		for (modalInteraction : scenario.chart.fragment.interactions) {
			process(modalInteraction)
		}

		val remove = <StateNode>newArrayList
		for (stateNode : firstRegion.stateNodes) {
			if (stateNode.incomingTransitions.isEmpty && stateNode.name != scenarioStatechartUtil.initial)
				remove += stateNode
		}
		firstRegion.stateNodes -= remove
		val lastState = firstRegion.stateNodes.get(firstRegion.stateNodes.size - 1)
		lastState.name = scenarioStatechartUtil.accepting

		for (transition : statechart.transitions) {
			if (transition.getTargetState == coldViolation) {
				transition.effects += setIntVariable(variableMap.getOrCreate(scenarioStatechartUtil.result), 1)
			} else if (transition.targetState == hotViolation) {
				transition.effects += setIntVariable(variableMap.getOrCreate(scenarioStatechartUtil.result), 0)
			} else if (transition.targetState == lastState) {
				transition.effects += setIntVariable(variableMap.getOrCreate(scenarioStatechartUtil.result), 2)
			}
		}

		val newMergeStates = newArrayList
		val states = firstRegion.stateNodes
		for (stateNode : states) {
			if (stateNode instanceof ChoiceState && stateNode.incomingTransitions.size > 1) {
				val choice = stateNode
				val merge = createMergeState
				merge.name = scenarioStatechartUtil.mergeName + stateCount++
				for (transition : choice.incomingTransitions) {
					transition.targetState = merge
				}
				val transition = createTransition
				transition.sourceState = merge
				transition.targetState = choice
				statechart.transitions += transition
				newMergeStates += merge
			}
		}
		states += newMergeStates

		val annotation = createScenarioContractAnnotation
		annotation.monitoredComponent = component
		annotation.scenarioType = nonDeclaredMessageMode
		statechart.annotations += annotation

		val waitingAnnotation = createScenarioAllowedWaitAnnotation
		waitingAnnotation.lowerLimit = allowedGlobalWaitMin.toIntegerLiteral
		waitingAnnotation.upperLimit = allowedGlobalWaitMax.toIntegerLiteral
		statechart.annotations += waitingAnnotation
		return statechart
	}

	def protected initializeStateChart(String scenarioName) {
		addPorts(component)
		statechart.transitionPriority = TransitionPriority.VALUE_BASED
		statechart.name = scenarioName
		firstRegion = createRegion
		firstRegion.name = firstRegionName
		statechart.regions += firstRegion

		val initial = createInitialState
		initial.name = scenarioStatechartUtil.initial
		firstRegion.stateNodes += initial

		val firstState = createState
		firstState.name = firstStateName
		firstRegion.stateNodes += firstState
		previousState = firstState
		var tmp = createNewState(scenarioStatechartUtil.hotViolation)
		firstRegion.stateNodes += tmp
		hotViolation = tmp;
		if (coldViolationExisits) {
			tmp = createNewState(scenarioStatechartUtil.coldViolation)
			firstRegion.stateNodes += tmp
			coldViolation = tmp
		} else {
			coldViolation = firstState
		}

		val initBlock = scenario.initialblock
		if (initBlock === null) {
			val t = statechartUtil.createTransition(initial, firstState)
			t.effects += setIntVariable(variableMap.getOrCreate(scenarioStatechartUtil.iteratingVariable), 1)
			t.effects +=
				setIntVariable(variableMap.getOrCreate(scenarioStatechartUtil.getLoopvariableNameForDepth(0)), 1)
		} else {
			val initChoice = createNewChoiceState
			firstRegion.stateNodes += initChoice
			statechartUtil.createTransition(initial, initChoice)
			val t2 = statechartUtil.createTransition(initChoice, firstState)
			for (interaction : initBlock.modalInteractions) {
				val a = getRaiseEventAction(interaction, false)
				if (a !== null) {
					t2.effects += a
				}
			}
			t2.effects +=
				setIntVariable(variableMap.getOrCreate(scenarioStatechartUtil.getLoopvariableNameForDepth(0)), 1)
			statechart.transitions += t2

			val violation = (initBlock.modalInteractions.get(0).modality ==
					ModalityType.HOT) ? hotViolation : coldViolation
			val t3 = statechartUtil.createTransition(initChoice, violation)
			t3.guard = createElseExpression
		}
	}

	def protected addPorts(Component c) {
		for (port : c.ports) {
			val pcopy = createPort
			val iReali = createInterfaceRealization
			iReali.realizationMode = port.interfaceRealization.realizationMode
			iReali.interface = port.interfaceRealization.interface
			pcopy.interfaceRealization = iReali
			pcopy.name = port.name
			statechart.ports += pcopy
			val preverse = createPort
			preverse.name = scenarioStatechartUtil.getTurnedOutPortName(port)
			val iRealiR = createInterfaceRealization
			iRealiR.interface = port.interfaceRealization.interface
			iRealiR.realizationMode = port.interfaceRealization.realizationMode.opposite
			preverse.interfaceRealization = iRealiR
			statechart.ports += preverse
		}
	}

	def dispatch void process(ModalInteractionSet interactionSet) {
		processModalInteractionSet(interactionSet, false)
	}

	def dispatch void process(Delay delay) {
		val newState = createNewState()
		firstRegion.stateNodes += newState
		val transition = statechartUtil.createTransition(previousState, newState)
		val timeoutDecl = createTimeoutDeclaration
		timeoutDecl.name = "delay" + timeoutCount++
		statechart.timeoutDeclarations += timeoutDecl
		val timeSpecification = createTimeSpecification
		timeSpecification.unit = TimeUnit.MILLISECOND
		timeSpecification.value = delay.minimum.clone
		val timeoutAction = createSetTimeoutAction
		timeoutAction.timeoutDeclaration = timeoutDecl
		timeoutAction.time = timeSpecification
		if (previousState instanceof State) {
			previousState.entryActions += timeoutAction
		}
		val eventTrigger = createEventTrigger
		val eventRef = createTimeoutEventReference
		eventRef.timeout = timeoutDecl
		transition.trigger = eventTrigger
		eventTrigger.eventReference = eventRef
		var StateNode violationState = (delay.modality == ModalityType.COLD) ? coldViolation : hotViolation
		val violationTransition = statechartUtil.createTransition(previousState, violationState)
		val violationTrigger = createEventTrigger
		val violationRventRef = createTimeoutEventReference
		violationRventRef.setTimeout(timeoutDecl)
		violationTrigger.eventReference = violationRventRef
		violationTransition.trigger = negateEventTrigger(violationTrigger)
		previousState = newState
	}

	def dispatch void process(NegatedModalInteraction negatedModalInteraction) {
		val modalInteraction = negatedModalInteraction.modalinteraction
		if (modalInteraction instanceof ModalInteractionSet) {
			processModalInteractionSet(modalInteraction, true)
		}
	}

	def dispatch void process(AlternativeCombinedFragment a) {
		val ends = newArrayList
		val choice = createNewChoiceState
		for (transition : previousState.incomingTransitions) {
			transition.targetState = choice
		}
		replacedStateWithValue.put(previousState, choice)
		firstRegion.stateNodes -= previousState
		firstRegion.stateNodes += choice
		val n = stateCount++
		for (i : 0 ..< a.fragments.size) {
			val state = createNewState(scenarioStatechartUtil.stateName + String.valueOf(n) + "_" + String.valueOf(i))
			previousState = state
			firstRegion.stateNodes += state
			statechartUtil.createTransition(choice, state)
			for (interaction : a.fragments.get(i).interactions) {
				process(interaction)
			}
			ends += previousState
			stateCount--
		}
		var merg = createState
		for (transition : statechart.transitions) {
			if (ends.contains(transition.targetState)) {
				transition.targetState = merg
			}
		}
		firstRegion.stateNodes -= ends
		merg.name = scenarioStatechartUtil.mergeName + String.valueOf(exsistingMerges++)
		firstRegion.stateNodes += merg
		previousState = merg
	}

	def dispatch void process(LoopCombinedFragment loop) {
		val loopDepth = scenarioStatechartUtil.getLoopDepth(loop)
		var prevprev = previousState
		for (interaction : loop.fragments.get(0).interactions) {
			interaction.process
		}
		if (replacedStateWithValue.containsKey(prevprev)) {
			prevprev = replacedStateWithValue -= prevprev
		}
		val choice = createNewChoiceState
		for (transition : previousState.incomingTransitions) {
			transition.targetState = choice
		}

		replacedStateWithValue.put(previousState, choice)
		firstRegion.stateNodes -= previousState
		firstRegion.stateNodes += choice
		val stateNew = createNewState()
		previousState = stateNew
		firstRegion.stateNodes += stateNew
		val t1 = statechartUtil.createTransition(choice, stateNew)
		val t2 = statechartUtil.createTransition(choice, prevprev)

		val variableForDepth = variableMap.getOrCreate(scenarioStatechartUtil.getLoopvariableNameForDepth(loopDepth))
		t1.guard = getVariableGreaterEqualParamExpression(variableForDepth, exprEval.evaluateInteger(loop.minimum))
		val maxCheck = createLessExpression
		maxCheck.leftOperand = exprUtil.createReferenceExpression(variableForDepth)
		maxCheck.rightOperand = exprUtil.toIntegerLiteral(exprEval.evaluateInteger(loop.maximum))
		t2.guard = maxCheck
		t2.effects += incrementVar(variableForDepth)
		t1.effects += setIntVariable(variableForDepth, 1)
	}

	def dispatch void process(OptionalCombinedFragment optionalCombinedFragment) {
		val choice = createNewChoiceState
		for (transition : statechart.transitions) {
			if (transition.targetState.equals(previousState)) {
				transition.targetState = choice
			}
		}
		replacedStateWithValue.put(previousState, choice)
		firstRegion.stateNodes -= previousState
		firstRegion.stateNodes += choice
		val stateNew = createNewState()
		previousState = stateNew
		firstRegion.stateNodes += stateNew
		val firstFragment = optionalCombinedFragment.fragments.get(0)
		for (interaction : firstFragment.interactions) {
			process(interaction)
		}
		statechartUtil.createTransition(choice, stateNew)
		statechartUtil.createTransition(choice, previousState)
	}

	def processModalInteractionSet(ModalInteractionSet set, boolean isNegated) {
		val state = createNewState
		val newChoice = createNewChoiceState
		firstRegion.stateNodes += newChoice
		firstRegion.stateNodes += state
		val dir = set.direction
		val mod = set.modality
		val forwardTransition = statechartUtil.createTransition(newChoice, state)
		val violationTransition = statechartUtil.createTransition(newChoice,
			(mod == ModalityType.COLD) ? coldViolation : hotViolation)
		val cycleTransition = statechartUtil.createTransition(previousState, newChoice)
		cycleTransition.trigger = createOnCycleTrigger
		val backwardTransition = createTransition
		violationTransition.guard = createElseExpression

		if (set.modalInteractions.empty) {
			val t = statechartUtil.createTransition(previousState, state)
			t.trigger = createOnCycleTrigger
			t.guard = createTrueExpression
			firstRegion.stateNodes += state
			previousState = state
			return
		}
		handleDelays(set)
		setupForwardTransition(set, dir.equals(InteractionDirection.SEND), isNegated, forwardTransition)

		if (nonDeclaredMessageMode == NotDefinedEventMode.STRICT) {
			val binary = createBinaryTrigger
			binary.leftOperand = forwardTransition.trigger
			binary.rightOperand = getBinaryTriggerFromTriggers(createOtherNegatedTriggers(set), BinaryType.AND)
			binary.type = BinaryType.AND
			forwardTransition.trigger = binary
		}

		if (dir.equals(InteractionDirection.SEND)) {
			handleSends(set, isNegated, forwardTransition, backwardTransition, cycleTransition, violationTransition,
				newChoice)
		}
		handleArguments(set.modalInteractions, forwardTransition);
		handleSingleNegatedIfNeeded(set, forwardTransition, violationTransition)
		previousState = state
		return
	}

	def handleSends(ModalInteractionSet set, boolean isNegated, Transition forwardTransition,
		Transition backwardTransition, Transition cycleTransition, Transition violationTransition,
		ChoiceState newChoice) {
		val iteratingVariable = variableMap.getOrCreate(scenarioStatechartUtil.iteratingVariable)

		forwardTransition.priority = BigInteger.valueOf(3)
		backwardTransition.priority = BigInteger.valueOf(2)
		violationTransition.priority = BigInteger.valueOf(1)
		backwardTransition.sourceState = newChoice
		backwardTransition.targetState = previousState
		backwardTransition.effects += incrementVar(iteratingVariable)
		backwardTransition.guard = getVariableLessEqualParamExpression(iteratingVariable, allowedGlobalWaitMax)

		if (generationMode != StatechartGenerationMode.GENERATE_ONLY_FORWARD) {
			forwardTransition.guard = getVariableInIntervalExpression(iteratingVariable, allowedGlobalWaitMin,
				allowedGlobalWaitMax)
			forwardTransition.effects += setIntVariable(iteratingVariable, 0)
		}

		val onlyNegated = set.isAllInteractionsOrBlockNegated || isNegated
		val NotDefinedEventMode mode = (onlyNegated) ? nonDeclaredNegMessageMode : nonDeclaredMessageMode
		if (!onlyNegated || mode == NotDefinedEventMode.STRICT) {
			// does not need to be added for allneg and strict, as it is overshadowed by the forward going transition
			statechart.transitions += backwardTransition
		}

		if (mode == NotDefinedEventMode.STRICT) {
			val BinaryTrigger tmp = getAllEvents(BinaryType.AND)
			negateBinaryTree(tmp)
			backwardTransition.trigger = tmp
		}

		if (onlyNegated) {
			forwardTransition.guard = null
			val maxCheck = createLessExpression
			maxCheck.leftOperand = exprUtil.createReferenceExpression(
				variableMap.getOrCreate(scenarioStatechartUtil.iteratingVariable))
			maxCheck.rightOperand = exprUtil.toIntegerLiteral(allowedGlobalWaitNegMax)
			backwardTransition.guard = maxCheck
		}

		switch (generationMode) {
			case GENERATE_MERGE_STATE: { // legacy option, not used currently
				val mergeState = createMergeState
				mergeState.name = scenarioStatechartUtil.mergeName + stateCount++
				for (transition : statechart.transitions) {
					if (transition.targetState == previousState && transition !== backwardTransition) {
						transition.targetState = mergeState
					}
				}
				firstRegion.stateNodes += mergeState
				statechartUtil.createTransition(mergeState, newChoice)
				cycleTransition.targetState = mergeState
			}
			case GENERATE_ONLY_FORWARD: {
				statechart.transitions -= backwardTransition
			}
			case GENERATE_DUPLICATED_CHOICES: { // legacy option, not used currently
				for (transition : previousState.incomingTransitions) {
					if (transition.sourceState !== newChoice) {
						val tmpChoice2 = createNewChoiceState
						val forwardCopy = forwardTransition.clone
						val violationCopy = violationTransition.clone
						val t3Copy = backwardTransition.clone
						t3Copy.sourceState = tmpChoice2
						forwardCopy.sourceState = tmpChoice2
						violationCopy.sourceState = tmpChoice2
						transition.targetState = tmpChoice2
						firstRegion.stateNodes += tmpChoice2
						statechart.transitions += t3Copy
						statechart.transitions += forwardCopy
						statechart.transitions += violationCopy
					}
				}
			}
			case GENERATE_ORIGINAL_STRUCTURE: {
				// does not need to be changed
			}
			default: {
				throw new IllegalArgumentException("Unhandled generation mode.")
			}
		}
	}

	def handleSingleNegatedIfNeeded(ModalInteractionSet set, Transition forwardTransition,
		Transition violationTransition) {
			var Signal signal = null
		var singleNegetedSignalWithArguments = false
		val firstModalinteraction = set.modalInteractions.get(0)
		if (set.modalInteractions.size == 1 && firstModalinteraction instanceof NegatedModalInteraction) {
			val negatedModalInteraction = firstModalinteraction as NegatedModalInteraction
			val innerModalInteraction = negatedModalInteraction.modalinteraction
			if (innerModalInteraction instanceof Signal) {
				singleNegetedSignalWithArguments = !(innerModalInteraction.arguments.empty)
				if(singleNegetedSignalWithArguments){
					signal = innerModalInteraction
				}
			}
		}
		if (singleNegetedSignalWithArguments) {
			if (!signal.arguments.empty) {
				val tmp = violationTransition.targetState
				violationTransition.targetState = forwardTransition.targetState
				forwardTransition.targetState = tmp
				forwardTransition.trigger = negateEventTrigger(forwardTransition.trigger)

			}
		}
	}

	def setupForwardTransition(ModalInteractionSet set, boolean reversed, boolean isNegated,
		Transition forwardTransition) {
		var Trigger trigger = null
		if (set.modalInteractions.size > 1) {
			trigger = getBinaryTrigger(set.modalInteractions, BinaryType.AND, reversed)
		} else {
			trigger = getEventTrigger(set.modalInteractions.get(0), reversed)
		}

		if (isNegated) {
			forwardTransition.trigger = negateEventTrigger(trigger)
		} else {
			forwardTransition.trigger = trigger
			for (modalInteraction : set.modalInteractions) {
				val effect = getRaiseEventAction(modalInteraction, !reversed)
				if (effect !== null) {
					forwardTransition.effects += effect
				}
			}
		}
	}

	def handleDelays(ModalInteractionSet set) {
		val delays = set.modalInteractions.filter(Delay)
		if (!delays.empty) {
			val delay = delays.get(0) as Delay
			val timeoutDeclaration = createTimeoutDeclaration
			timeoutDeclaration.name = "delay" + timeoutCount++
			statechart.timeoutDeclarations += timeoutDeclaration
			val timeSpecification = createTimeSpecification
			timeSpecification.unit = TimeUnit.MILLISECOND
			timeSpecification.value = delay.minimum.clone
			val action = createSetTimeoutAction
			action.timeoutDeclaration = timeoutDeclaration
			action.time = timeSpecification
			if (previousState instanceof State) {
				previousState.entryActions += action
			}
		}
	}

	def handleArguments(List<InteractionDefinition> set, Transition transition) {
		var signals = set.filter(Signal).filter[!it.arguments.empty]
		if (signals.empty) {
			val firstInteraction  = set.get(0)
			if (set.size == 1 && firstInteraction instanceof NegatedModalInteraction) {
				val interaction = firstInteraction as NegatedModalInteraction
				if (interaction.modalinteraction instanceof Signal) {
					val signal = interaction.modalinteraction as Signal
					if (!signal.arguments.empty) {
						signals = newArrayList(signal)
					}
				}
			}
		}
		if (signals.empty) {
			return
		}
		val guard1 = createAndExpression
		for (signal : signals) {
			val tmp = signal
			var i = 0
			var String portName = tmp.port.name
			if (tmp.direction.equals(InteractionDirection.SEND)) {
				if (!scenarioStatechartUtil.isTurnedOut(tmp.port)) {
					portName = scenarioStatechartUtil.getTurnedOutPortName(tmp.port)
				}
			}
			val port = getPort(portName)
			val event = getEvent(tmp.event.name, port)
			for (paramDec : event.parameterDeclarations) {
				val paramRef = createEventParameterReferenceExpression
				paramRef.parameter = paramDec
				paramRef.port = port
				paramRef.event = event
				guard1.operands += createEqualityExpression(paramRef, tmp.arguments.get(i).clone)
				i++
			}
		}
		var Expression expr = null
		if (guard1.operands.size == 1) {
			expr = guard1.operands.get(0)
		} else {
			expr = guard1
		}
		val guard = transition.guard
		if (guard === null) {
			transition.guard = expr
		} else {
			val and = createAndExpression
			and.operands += expr
			and.operands += guard
			transition.guard = and
		}
	}

}
