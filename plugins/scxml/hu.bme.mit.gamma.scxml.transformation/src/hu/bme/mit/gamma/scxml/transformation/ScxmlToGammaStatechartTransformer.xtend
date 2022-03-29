package hu.bme.mit.gamma.scxml.transformation

import ac.soton.scxml.ScxmlFinalType
import ac.soton.scxml.ScxmlInitialType
import ac.soton.scxml.ScxmlParallelType
import ac.soton.scxml.ScxmlScxmlType
import ac.soton.scxml.ScxmlStateType
import ac.soton.scxml.ScxmlTransitionType
import hu.bme.mit.gamma.statechart.statechart.InitialState
import hu.bme.mit.gamma.statechart.statechart.State
import hu.bme.mit.gamma.statechart.statechart.SynchronousStatechartDefinition
import hu.bme.mit.gamma.statechart.statechart.Transition
import java.util.HashMap
import java.util.logging.Level

import static ac.soton.scxml.ScxmlModelDerivedFeatures.*
import static hu.bme.mit.gamma.scxml.transformation.Namings.*

// TODO Transform not only the first transition in a target state specification, but all of them.
class ScxmlToGammaStatechartTransformer extends AbstractTransformer {
	
	// Root element of the SCXML statechart model to transform
	protected final ScxmlScxmlType scxmlRoot
	
	// Root element of the Gamma statechart definition as the transformation result
	protected final SynchronousStatechartDefinition gammaStatechart
	
	new(ScxmlScxmlType scxmlRoot) {
		this(scxmlRoot,
			new Traceability(scxmlRoot)
		)
	}
	
	new(ScxmlScxmlType scxmlRoot, Traceability traceability) {
		super(traceability)
		
		this.scxmlRoot = scxmlRoot
		this.gammaStatechart = createSynchronousStatechartDefinition => [
			it.name = getStatechartName(scxmlRoot)
		]
	}
	
	// Transformation of the SCXML root element and its contents recursively
	def execute() {
		traceability.put(scxmlRoot, gammaStatechart)
		
		logger.log(Level.INFO, "Transforming <scxml> root element (" + scxmlRoot.name + ")")
		
		val mainRegion = createRegion => [
			it.name = getRegionName(scxmlRoot.name)
		]
		gammaStatechart.regions += mainRegion
		
		val scxmlStateNodes = getStateNodes(scxmlRoot)
		for (scxmlStateNode : scxmlStateNodes) {
			if (isParallel(scxmlStateNode)) {
				val parallel = scxmlStateNode as ScxmlParallelType
				mainRegion.stateNodes += parallel.transformParallel
			}
			else if (scxmlStateNode instanceof ScxmlStateType) {
				mainRegion.stateNodes += scxmlStateNode.transformState
			}
			else if (isFinal(scxmlStateNode)) {
				val final = scxmlStateNode as ScxmlFinalType
				mainRegion.stateNodes += final.transformFinal
			}
			else {
				throw new IllegalArgumentException(
					"Object " + scxmlStateNode + " is of unknown SCXML <state> type.")
			}
		}
		
		val transitions = getAllTransitions(scxmlRoot)
		for (transition : transitions) {
			transition.transformTransition
		}
		
		// Transform the SCXML root element's initial attribute,
		// or select its first child as initial state if it is not present.
		val gammaInitial = createInitialState => [
			it.name = getInitialName(scxmlRoot)
		]
		mainRegion.stateNodes += gammaInitial	
		
		val scxmlInitialAttribute = scxmlRoot.initial
		val scxmlFirstInitialAttribute = scxmlInitialAttribute?.head
		if (scxmlFirstInitialAttribute !== null) {
			val gammaInitialTarget = traceability.getStateById(scxmlFirstInitialAttribute)
			gammaInitial.createTransition(gammaInitialTarget)
		}
		else {
			val firstScxmlStateChild = getFirstChildStateNode(scxmlRoot) as ScxmlStateType
			val gammaInitialTarget = traceability.getState(firstScxmlStateChild)
			gammaInitial.createTransition(gammaInitialTarget)
		}
		
		return traceability
	}
	
	protected def State transformParallel(ScxmlParallelType parallelNode) {
		logger.log(Level.INFO, "Transforming <parallel> element (" + parallelNode.id + ")")
		
		val gammaParallel = createState => [
			it.name = getParallelName(parallelNode)
		]
		
		val scxmlStateNodes = getStateNodes(parallelNode)
		
		for (scxmlStateNode : scxmlStateNodes) {
			val region = createRegion => [
				it.name = getRegionName(gammaParallel.name)
			]
			gammaParallel.regions += region
			
			if (isParallel(scxmlStateNode)) {
				val parallel = scxmlStateNode as ScxmlParallelType
				region.stateNodes += parallel.transformParallel
			}
			else if (isState(scxmlStateNode)) {
				val state = scxmlStateNode as ScxmlStateType
				region.stateNodes += state.transformState
			}
			else if (isFinal(scxmlStateNode)) {
				val final = scxmlStateNode as ScxmlFinalType
				region.stateNodes += final.transformFinal
			}
			else {
				throw new IllegalArgumentException(
					"Object " + scxmlStateNode + " is of unknown SCXML <state> type.")
			}
		}
		
		traceability.put(parallelNode, gammaParallel)
		
		return gammaParallel
	}
	
	protected def State transformState(ScxmlStateType scxmlState) {
		logger.log(Level.INFO, "Transforming <state> element (" + scxmlState.id + ")")
		
		val gammaState = createState => [
			it.name = getStateName(scxmlState)
		]
		
		if (isCompoundState(scxmlState)) {
			val region = createRegion => [
				it.name = getRegionName(gammaState.name)
			]
			gammaState.regions += region
				
			val scxmlStateNodes = getStateNodes(scxmlState)
			
			for (scxmlStateNode : scxmlStateNodes) {
				if (isParallel(scxmlStateNode)) {
					val parallel = scxmlStateNode as ScxmlParallelType
					region.stateNodes += parallel.transformParallel
				}
				else if (isState(scxmlStateNode)) {
					val state = scxmlStateNode as ScxmlStateType
					region.stateNodes += state.transformState
				}
				else if (isFinal(scxmlStateNode)) {
					val final = scxmlStateNode as ScxmlFinalType
					region.stateNodes += final.transformFinal
				}
				else {
					throw new IllegalArgumentException(
						"Object " + scxmlStateNode + " is of unknown SCXML <state> type.")
				}
			}
			
			// Transform the state's initial element or attribute,
			// or select its first child as initial state if neither one above is present.
			val scxmlInitialElement = scxmlState.initial.head
			if (scxmlInitialElement !== null) {
				region.stateNodes += scxmlInitialElement.transformInitial
			}
			else {
				val gammaInitial = createInitialState => [
					it.name = getInitialName(scxmlState)
				]
				region.stateNodes += gammaInitial	
				
				val scxmlInitialAttribute = scxmlState.initial1.head
				if (scxmlInitialAttribute !== null) {
					val gammaInitialTarget = traceability.getStateById(scxmlInitialAttribute)
					gammaInitial.createTransition(gammaInitialTarget)
				}
				else {
					val firstScxmlStateChild = getFirstChildStateNode(scxmlState) as ScxmlStateType
					val gammaInitialTarget = traceability.getState(firstScxmlStateChild)
					gammaInitial.createTransition(gammaInitialTarget)
				}
			}
		}		
		
		traceability.put(scxmlState, gammaState)
		
		return gammaState
	}
	
	protected def State transformFinal(ScxmlFinalType scxmlFinal) {
		logger.log(Level.INFO, "Transforming <final> element (" + scxmlFinal.id + ")")
		
		val gammaFinal = createState => [
			it.name = getFinalName(scxmlFinal)
		]
		
		traceability.put(scxmlFinal, gammaFinal)
		
		return gammaFinal
	}
	
	protected def InitialState transformInitial(ScxmlInitialType scxmlInitial) {
		logger.log(Level.INFO, "Transforming <initial> element")
		
		val parentState = getParentState(scxmlInitial)
		val gammaInitial = createInitialState => [
			it.name = getInitialName(parentState)
		]
		
		traceability.put(scxmlInitial, gammaInitial)
		
		return gammaInitial
	}
	
	protected def Transition transformTransition(ScxmlTransitionType transition) {
		// TODO For now, only ScxmlStateType is considered as a type of transition source.
		val sourceId = getParentStateNodeId(transition)
		val targetId = transition.target.head
		
		if (sourceId !== null) {
			val gammaSource = traceability.getStateById(sourceId)
			val gammaTarget = traceability.getStateById(targetId)
			
			logger.log(Level.INFO, "Transforming transition" + sourceId + " -> " + targetId)
			
			val gammaTransition = gammaSource.createTransition(gammaTarget)
			
			val guardStr = transition.cond
			if (guardStr !== null) {
				val gammaGuardExpression = conditionalLanguageParser
											.parse(guardStr, new HashMap)
				gammaTransition.guard = gammaGuardExpression
			}
			
			traceability.put(transition, gammaTransition)
			
			return gammaTransition
		}
		
		return null
	}
	
}