/********************************************************************************
 * Copyright (c) 2018 Contributors to the Gamma project
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * SPDX-License-Identifier: EPL-1.0
 ********************************************************************************/
package hu.bme.mit.gamma.uppaal.composition.transformation

import hu.bme.mit.gamma.action.model.AssignmentStatement
import hu.bme.mit.gamma.statechart.model.EntryState
import hu.bme.mit.gamma.statechart.model.Package
import hu.bme.mit.gamma.statechart.model.Port
import hu.bme.mit.gamma.statechart.model.RaiseEventAction
import hu.bme.mit.gamma.statechart.model.Region
import hu.bme.mit.gamma.statechart.model.State
import hu.bme.mit.gamma.statechart.model.StateNode
import hu.bme.mit.gamma.statechart.model.StatechartDefinition
import hu.bme.mit.gamma.statechart.model.TimeSpecification
import hu.bme.mit.gamma.statechart.model.Transition
import hu.bme.mit.gamma.statechart.model.TransitionPriority
import hu.bme.mit.gamma.statechart.model.composite.AsynchronousComponent
import hu.bme.mit.gamma.statechart.model.composite.Component
import hu.bme.mit.gamma.statechart.model.composite.ComponentInstance
import hu.bme.mit.gamma.statechart.model.composite.SynchronousComponentInstance
import hu.bme.mit.gamma.statechart.model.interface_.Event
import hu.bme.mit.gamma.uppaal.composition.transformation.AsynchronousSchedulerTemplateCreator.Scheduler
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.EdgesWithClock
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.InputInstanceEvents
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.InstanceRegions
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.InstanceVariables
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.ParameteredEvents
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.ParameterizedInstances
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.RaiseInstanceEventOfTransitions
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.RaiseInstanceEventStateEntryActions
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.RaiseInstanceEventStateExitActions
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.RaiseTopSystemEventOfTransitions
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.RaiseTopSystemEventStateEntryActions
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.RaiseTopSystemEventStateExitActions
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.ToHigherInstanceTransitions
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.ToLowerInstanceTransitions
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.TopSyncSystemOutEvents
import hu.bme.mit.gamma.uppaal.transformation.queries.AllSubregionsOfCompositeStates
import hu.bme.mit.gamma.uppaal.transformation.queries.ChoicesAndMerges
import hu.bme.mit.gamma.uppaal.transformation.queries.CompositeStates
import hu.bme.mit.gamma.uppaal.transformation.queries.ConstantDeclarations
import hu.bme.mit.gamma.uppaal.transformation.queries.DeclarationInitializations
import hu.bme.mit.gamma.uppaal.transformation.queries.DefaultTransitionsOfChoices
import hu.bme.mit.gamma.uppaal.transformation.queries.Entries
import hu.bme.mit.gamma.uppaal.transformation.queries.EntryAssignmentsOfStates
import hu.bme.mit.gamma.uppaal.transformation.queries.EntryRaisingActionsOfStates
import hu.bme.mit.gamma.uppaal.transformation.queries.EntryTimeoutActionsOfStates
import hu.bme.mit.gamma.uppaal.transformation.queries.EventTriggersOfTransitions
import hu.bme.mit.gamma.uppaal.transformation.queries.ExitAssignmentsOfStatesWithTransitions
import hu.bme.mit.gamma.uppaal.transformation.queries.ExitRaisingActionsOfStatesWithTransitions
import hu.bme.mit.gamma.uppaal.transformation.queries.GuardsOfTransitions
import hu.bme.mit.gamma.uppaal.transformation.queries.OutgoingTransitionsOfCompositeStates
import hu.bme.mit.gamma.uppaal.transformation.queries.RaisingActionsOfTransitions
import hu.bme.mit.gamma.uppaal.transformation.queries.SameRegionTransitions
import hu.bme.mit.gamma.uppaal.transformation.queries.SimpleStates
import hu.bme.mit.gamma.uppaal.transformation.queries.States
import hu.bme.mit.gamma.uppaal.transformation.queries.TimeTriggersOfTransitions
import hu.bme.mit.gamma.uppaal.transformation.queries.ToHigherTransitions
import hu.bme.mit.gamma.uppaal.transformation.queries.Transitions
import hu.bme.mit.gamma.uppaal.transformation.queries.UpdatesOfTransitions
import hu.bme.mit.gamma.uppaal.transformation.traceability.G2UTrace
import hu.bme.mit.gamma.uppaal.transformation.traceability.TraceabilityFactory
import hu.bme.mit.gamma.uppaal.transformation.traceability.TraceabilityPackage
import java.util.AbstractMap.SimpleEntry
import java.util.ArrayList
import java.util.Collection
import java.util.HashMap
import java.util.HashSet
import java.util.List
import java.util.Map
import java.util.Set
import java.util.logging.Level
import java.util.logging.Logger
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.viatra.query.runtime.api.ViatraQueryEngine
import org.eclipse.viatra.query.runtime.emf.EMFScope
import org.eclipse.viatra.transformation.runtime.emf.modelmanipulation.IModelManipulations
import org.eclipse.viatra.transformation.runtime.emf.modelmanipulation.SimpleModelManipulations
import org.eclipse.viatra.transformation.runtime.emf.rules.batch.BatchTransformationRuleFactory
import org.eclipse.viatra.transformation.runtime.emf.transformation.batch.BatchTransformation
import org.eclipse.viatra.transformation.runtime.emf.transformation.batch.BatchTransformationStatements
import uppaal.NTA
import uppaal.UppaalFactory
import uppaal.UppaalPackage
import uppaal.declarations.ChannelVariableDeclaration
import uppaal.declarations.ClockVariableDeclaration
import uppaal.declarations.DataVariableDeclaration
import uppaal.declarations.DataVariablePrefix
import uppaal.declarations.DeclarationsFactory
import uppaal.declarations.DeclarationsPackage
import uppaal.declarations.ExpressionInitializer
import uppaal.declarations.Function
import uppaal.declarations.FunctionDeclaration
import uppaal.declarations.LocalDeclarations
import uppaal.declarations.SystemDeclarations
import uppaal.declarations.TypeDeclaration
import uppaal.declarations.VariableDeclaration
import uppaal.declarations.system.InstantiationList
import uppaal.declarations.system.SystemPackage
import uppaal.expressions.AssignmentExpression
import uppaal.expressions.AssignmentOperator
import uppaal.expressions.CompareOperator
import uppaal.expressions.Expression
import uppaal.expressions.ExpressionsFactory
import uppaal.expressions.ExpressionsPackage
import uppaal.expressions.IdentifierExpression
import uppaal.expressions.LiteralExpression
import uppaal.expressions.LogicalExpression
import uppaal.expressions.LogicalOperator
import uppaal.expressions.NegationExpression
import uppaal.statements.Block
import uppaal.statements.ExpressionStatement
import uppaal.statements.ReturnStatement
import uppaal.statements.StatementsPackage
import uppaal.templates.Edge
import uppaal.templates.Location
import uppaal.templates.LocationKind
import uppaal.templates.SynchronizationKind
import uppaal.templates.Template
import uppaal.templates.TemplatesPackage
import uppaal.types.BuiltInType
import uppaal.types.DeclaredType
import uppaal.types.PredefinedType
import uppaal.types.StructTypeSpecification
import uppaal.types.TypeReference
import uppaal.types.TypesPackage

import static com.google.common.base.Preconditions.checkState

import static extension hu.bme.mit.gamma.statechart.model.derivedfeatures.StatechartModelDerivedFeatures.*
import static extension hu.bme.mit.gamma.uppaal.composition.transformation.Namings.*

class CompositeToUppaalTransformer {
	// Transformation-related extensions
	protected extension BatchTransformation transformation
	protected extension BatchTransformationStatements statements
	// Transformation rule-related extensions
	protected extension BatchTransformationRuleFactory = new BatchTransformationRuleFactory
	protected extension IModelManipulations manipulation
	// Logger
	protected extension Logger logger = Logger.getLogger("GammaLogger")
	// Arguments for the top level component
	protected List<hu.bme.mit.gamma.expression.model.Expression> topComponentArguments = new ArrayList<hu.bme.mit.gamma.expression.model.Expression>
	// Engine on the Gamma resource 
	protected ViatraQueryEngine engine
	protected ResourceSet resources
	// The Gamma composite system to be transformed
	protected Component component
	// The Gamma statechart that contains all ComponentDeclarations with the required instances
	protected Package sourceRoot
	// Root element containing the traces
	protected G2UTrace traceRoot
	// The root element of the Uppaal automaton
	protected NTA target
	// Message struct types
	protected DeclaredType messageStructType
	protected StructTypeSpecification messageStructTypeDef
	protected DataVariableDeclaration messageEvent
	protected DataVariableDeclaration messageValue
	// Gamma package
	protected final extension TraceabilityPackage trPackage = TraceabilityPackage.eINSTANCE
	// UPPAAL packages
	protected final extension UppaalPackage upPackage = UppaalPackage.eINSTANCE
	protected final extension DeclarationsPackage declPackage = DeclarationsPackage.eINSTANCE
	protected final extension TypesPackage typPackage = TypesPackage.eINSTANCE
	protected final extension TemplatesPackage temPackage = TemplatesPackage.eINSTANCE
	protected final extension ExpressionsPackage expPackage = ExpressionsPackage.eINSTANCE
	protected final extension StatementsPackage stmPackage = StatementsPackage.eINSTANCE
	protected final extension SystemPackage sysPackage = SystemPackage.eINSTANCE
	// UPPAAL factories
	protected final extension DeclarationsFactory declFact = DeclarationsFactory.eINSTANCE
	protected final extension ExpressionsFactory expFact = ExpressionsFactory.eINSTANCE
	// isStable variable
	protected DataVariableDeclaration isStableVar
	// Async scheduler
	protected Scheduler asyncScheduler = Scheduler.RANDOM
	// Orchestrating period for top sync components
	protected TimeSpecification minimalOrchestratingPeriod
	protected TimeSpecification maximalOrchestratingPeriod
	// Minimal element set: no functions
	protected boolean isMinimalElementSet = false
	// For the generation of pseudo locations
	protected int id = 0
	// Transition ids
	protected final Set<SynchronousComponentInstance> testedComponentsForStates = newHashSet
	protected final Set<SynchronousComponentInstance> testedComponentsForTransitions = newHashSet
	protected DataVariableDeclaration transitionIdVar
	protected final int INITIAL_TRANSITION_ID = 1
	protected int transitionId = INITIAL_TRANSITION_ID
	// Trace
	protected extension Trace traceModel
	// Auxiliary objects
	protected extension VariableTransformer variableTransformer
	protected extension TriggerTransformer triggerTransformer
	protected extension NtaBuilder ntaBuilder
	protected extension ExpressionTransformer expressionTransformer
	protected extension ExpressionCopier expressionCopier
	protected extension ExpressionEvaluator expressionEvaluator
	protected extension CompareExpressionCreator compareExpressionCreator
	protected extension AsynchronousComponentHelper asynchronousComponentHelper
	protected extension AssignmentExpressionCreator assignmentExpressionCreator
	protected final extension SimpleInstanceHandler simpleInstanceHandler = new SimpleInstanceHandler
	protected final extension EventHandler eventHandler = new EventHandler
    protected final extension Cloner cloner = new Cloner
    protected final extension InPlaceExpressionTransformer inPlaceExpressionTransformer = new InPlaceExpressionTransformer
	// Auxiliary transformer objects
	protected AsynchronousConstantsCreator asynchronousConstantsCreator
	protected SynchronousChannelCreatorOfAsynchronousInstances synchronousChannelCreatorOfAsynchronousInstances
	protected MessageQueueCreator messageQueueCreator
	protected OrchestratorCreator orchestratorCreator
	protected EnvironmentCreator environmentCreator
	protected AsynchronousClockTemplateCreator asynchronousClockTemplateCreator
	protected AsynchronousSchedulerTemplateCreator asynchronousSchedulerTemplateCreator
	protected AsynchronousConnectorTemplateCreator asynchronousConnectorTemplateCreator
	
	new(ResourceSet resourceSet, Component component, Scheduler asyncScheduler,
			List<SynchronousComponentInstance> testedComponentsForStates,
			List<SynchronousComponentInstance> testedComponentsForTransitions) {
		this.initialize(resourceSet, component, asyncScheduler, testedComponentsForStates, testedComponentsForTransitions)
	}
	
	new(ResourceSet resourceSet, Component component,
			List<hu.bme.mit.gamma.expression.model.Expression> topComponentArguments,
			Scheduler asyncScheduler,
			TimeSpecification minimalOrchestratingPeriod,
			TimeSpecification maximalOrchestratingPeriod,
			boolean isMinimalElementSet,
			List<SynchronousComponentInstance> testedComponentsForStates,
			List<SynchronousComponentInstance> testedComponentsForTransitions) { 
		this.minimalOrchestratingPeriod = minimalOrchestratingPeriod
		this.maximalOrchestratingPeriod = maximalOrchestratingPeriod
		this.isMinimalElementSet = isMinimalElementSet
		this.topComponentArguments.addAll(topComponentArguments)
		// The above parameters have to be set before calling initialize
		this.initialize(resourceSet, component, asyncScheduler, testedComponentsForStates, testedComponentsForTransitions)
	}
	
	private def initialize(ResourceSet resourceSet, Component component, Scheduler asyncScheduler,
			List<SynchronousComponentInstance> testedComponentsForStates,
			List<SynchronousComponentInstance> testedComponentsForTransitions) {
		this.resources = resourceSet // sourceRoot.eResource.resourceSet does not work
		this.sourceRoot = component.eContainer as Package
		this.component = component
		this.asyncScheduler = asyncScheduler
		this.testedComponentsForStates += testedComponentsForStates // Only simple instances
		this.testedComponentsForTransitions += testedComponentsForTransitions // Only simple instances
		this.target = UppaalFactory.eINSTANCE.createNTA => [
			it.name = component.name
		]
		// Connecting the two models in trace
		this.traceRoot = TraceabilityFactory.eINSTANCE.createG2UTrace => [
			it.gammaPackage = this.sourceRoot
			it.nta = this.target
		]
		// Create VIATRA engine based on the Gamma resource
		this.engine = ViatraQueryEngine.on(new EMFScope(this.resources));	  
		// Create VIATRA auxiliary objects
		this.manipulation = new SimpleModelManipulations(engine)
		this.transformation = BatchTransformation.forEngine(engine).build
		this.statements = transformation.transformationStatements
		// Trace
		this.traceModel = new Trace(this.manipulation, this.traceRoot)
		// Auxiliary objects
		this.triggerTransformer = new TriggerTransformer(this.traceModel)
		this.expressionTransformer = new ExpressionTransformer(this.manipulation, this.traceModel)
		this.expressionCopier = new ExpressionCopier(this.manipulation, this.traceModel)
		this.expressionEvaluator = new ExpressionEvaluator(this.engine)
		this.ntaBuilder = new NtaBuilder(this.target, this.manipulation, this.isMinimalElementSet)
		this.variableTransformer = new VariableTransformer(this.ntaBuilder, this.manipulation, this.traceModel)
		this.assignmentExpressionCreator = new AssignmentExpressionCreator(this.ntaBuilder, 
			this.manipulation, this.expressionTransformer)
		this.compareExpressionCreator = new CompareExpressionCreator(this.ntaBuilder, this.manipulation,
			this.expressionTransformer, this.traceModel)
		this.asynchronousComponentHelper = new AsynchronousComponentHelper(this.component, this.engine,
			this.manipulation, this.expressionTransformer, this.ntaBuilder, this.traceModel)
		// Creating UPPAAL variable and type structures as multiple auxiliary transformers need them
		initNta
		createMessageStructType
		createIsStableVar
		if (!testedComponentsForTransitions.empty) {
			createTransitionIdVar
		}
		// Auxiliary transformation objects
		this.asynchronousConstantsCreator = new AsynchronousConstantsCreator(this.ntaBuilder, this.manipulation, this.traceModel)
		this.synchronousChannelCreatorOfAsynchronousInstances = new SynchronousChannelCreatorOfAsynchronousInstances(this.ntaBuilder, this.traceModel) 
		this.messageQueueCreator = new MessageQueueCreator(this.ntaBuilder, this.manipulation, this.engine, this.expressionTransformer, this.traceModel, 
			this.messageStructType, this.messageEvent, this.messageValue)
		this.orchestratorCreator = new OrchestratorCreator(this.ntaBuilder, this.engine, this.manipulation, this.assignmentExpressionCreator,
			this.compareExpressionCreator, this.minimalOrchestratingPeriod, this.maximalOrchestratingPeriod, this.traceModel, this.transitionIdVar, this.isStableVar)
		this.environmentCreator = new EnvironmentCreator(this.ntaBuilder, this.engine, this.manipulation,
			this.assignmentExpressionCreator, this.asynchronousComponentHelper, this.traceModel, this.isStableVar)
		this.asynchronousClockTemplateCreator = new AsynchronousClockTemplateCreator(this.ntaBuilder, this.engine, this.manipulation, this.compareExpressionCreator,
			this.traceModel, this.isStableVar, this.asynchronousComponentHelper, this.expressionTransformer)
		this.asynchronousSchedulerTemplateCreator = new AsynchronousSchedulerTemplateCreator(this.ntaBuilder, this.engine, this.manipulation, this.compareExpressionCreator,
			this.traceModel, this.isStableVar, this.asynchronousComponentHelper, this.expressionEvaluator, this.assignmentExpressionCreator,
			this.minimalOrchestratingPeriod, this.maximalOrchestratingPeriod, this.asyncScheduler)
		this.asynchronousConnectorTemplateCreator = new AsynchronousConnectorTemplateCreator(this.ntaBuilder, this.manipulation, this.assignmentExpressionCreator,
			this.asynchronousComponentHelper, this.expressionTransformer, this.traceModel, this.isStableVar, this.messageEvent, this.messageValue)
	}
	
	def execute() {
		transformTopComponentArguments
		while (!areAllParametersTransformed) {
			parametersRule.fireAllCurrent[!it.instance.areAllArgumentsTransformed]
		}
		constantsRule.fireAllCurrent
		variablesRule.fireAllCurrent
		declarationInitRule.fireAllCurrent
		inputEventsRule.fireAllCurrent
		syncSystemOutputEventsRule.fireAllCurrent
		eventParametersRule.fireAllCurrent
		regionsRule.fireAllCurrent
		entriesRule.fireAllCurrent
		statesRule.fireAllCurrent
		choicesRule.fireAllCurrent
		sameRegionTransitionsRule.fireAllCurrent
		toLowerRegionTransitionsRule.fireAllCurrent
		toHigherRegionTransitionsRule.fireAllCurrent		
	 	{eventTriggersRule.fireAllCurrent
		timeTriggersRule.fireAllCurrent} // Should come right after eventTriggersRule		
		{guardsRule.fireAllCurrent
		defultChoiceTransitionsRule.fireAllCurrent
		transitionPriorityRule.fireAllCurrent
		transitionTimedTransitionPriorityRule.fireAllCurrent}
		// Executed here, so locations created by timeTriggersRule have initialization edges (templates do not stick in timer locations)
		// Must be executed after swapGuardsOfTimeTriggerTransitions, otherwise an exception is thrown
		compositeStateEntryRule.fireAllCurrent 
		entryAssignmentActionsOfStatesRule.fireAllCurrent
		exitAssignmentActionsOfStatesRule.fireAllCurrent
		exitEventRaisingActionsOfStatesRule.fireAllCurrent
		exitSystemEventRaisingActionsOfStatesRule.fireAllCurrent
		assignmentActionsRule.fireAllCurrent[
			!ToHigherTransitions.Matcher.on(engine).allValuesOftransition.contains(it.transition)
		]	
		// Across region entry events are set here so they are situated after the exit events and regular transition assignments
		toLowerRegionEntryEventTransitionsRule.fireAllCurrent
		eventRaisingActionsRule.fireAllCurrent[
			!ToHigherTransitions.Matcher.on(engine).allValuesOftransition.contains(it.transition)
		]
		syncSystemEventRaisingActionsRule.fireAllCurrent
		entryEventRaisingActionsRule.fireAllCurrent
		syncSystemEventRaisingOfEntryActionsRule.fireAllCurrent
		compositeStateExitRule
		entryTimeoutActionsOfStatesRule.fireAllCurrent
		isActiveRule.fireAllCurrent
		// Extend timed locations with outgoing edges from the original location
		extendTimedLocations
		// Creating a same level process list, note that it is before the orchestrator template: UPPAAL does not work correctly with priorities
//		instantiateUninstantiatedTemplates
		// New entries to traces, previous adding would cause trouble
		extendTrace
		// Firing the rules for async components 
		{asynchronousConstantsCreator.getEventConstantsRule.fireAllCurrent[component instanceof AsynchronousComponent /*Needed only for async models*/]
		asynchronousConstantsCreator.getClockConstantsRule.fireAllCurrent[component instanceof AsynchronousComponent /*Needed only for async models*/]}
		{synchronousChannelCreatorOfAsynchronousInstances.getTopWrapperSyncChannelRule.fireAllCurrent
		synchronousChannelCreatorOfAsynchronousInstances.getInstanceWrapperSyncChannelRule.fireAllCurrent}
		// Creating the sync schedulers: here the scheduler template and the priorities are set
		{orchestratorCreator.getTopSyncOrchestratorRule.fireAllCurrent
		orchestratorCreator.getTopWrappedSyncOrchestratorRule.fireAllCurrent
		orchestratorCreator.getInstanceWrapperSyncOrchestratorRule.fireAllCurrent}
		// Message queue structures
		{messageQueueCreator.getTopMessageQueuesRule.fireAllCurrent
		messageQueueCreator.getInstanceMessageQueuesRule.fireAllCurrent}
		// "Environment" rules
		{environmentCreator.getTopSyncEnvironmentRule.fireAllCurrent // sync environment
		environmentCreator.getTopWrapperEnvironmentRule.fireAllCurrent
		environmentCreator.getInstanceWrapperEnvironmentRule.fireAllCurrent}
		{asynchronousClockTemplateCreator.getTopWrapperClocksRule.fireAllCurrent
		asynchronousClockTemplateCreator.getInstanceWrapperClocksRule.fireAllCurrent}
		{asynchronousSchedulerTemplateCreator.getTopWrapperSchedulerRule.fireAllCurrent
		asynchronousSchedulerTemplateCreator.getInstanceWrapperSchedulerRule.fireAllCurrent}
		{asynchronousConnectorTemplateCreator.getTopWrapperConnectorRule.fireAllCurrent
		asynchronousConnectorTemplateCreator.getInstanceWrapperConnectorRule.fireAllCurrent}
		// Creating a same level process list
		instantiateUninstantiatedTemplates
		if (!isMinimalElementSet) {
			createNoInnerEventsFunction
		}
		cleanUp
		// The created EMF models are returned
		return new SimpleEntry<NTA, G2UTrace>(target, traceRoot)
	}
	
	/**
	 * This method is responsible for the initialization of the NTA.
	 * It creates the global and system declaration collections and the predefined types.
	 */
	private def initNta() {
		target.createChild(getNTA_GlobalDeclarations, globalDeclarations)
		target.createChild(getNTA_SystemDeclarations, systemDeclarations) as SystemDeclarations => [
			it.createChild(systemDeclarations_System, sysPackage.system)
		]
		target.createChild(getNTA_Int, predefinedType) as PredefinedType => [
			it.name = "integer"
			it.type = BuiltInType.INT
		]
		target.createChild(getNTA_Bool, predefinedType) as PredefinedType => [
			it.name = "boolean"
			it.type = BuiltInType.BOOL
		]
		target.createChild(getNTA_Void, predefinedType) as PredefinedType => [
			it.name = "void"
			it.type = BuiltInType.VOID
		]
		target.createChild(getNTA_Clock, predefinedType) as PredefinedType => [
			it.name = "clock"
			it.type = BuiltInType.CLOCK
		]
		target.createChild(getNTA_Chan, predefinedType) as PredefinedType => [
			it.name = "channel"
			it.type = BuiltInType.CHAN
		]
	}
	
	private def createMessageStructType() {
		if (component instanceof AsynchronousComponent) {
			val messageTypeDecl = target.globalDeclarations.createChild(declarations_Declaration, typeDeclaration) as TypeDeclaration
			messageStructType = messageTypeDecl.createChild(typeDeclaration_Type, declaredType) as DeclaredType => [
				it.name = "Message"
				it.typeDeclaration = messageTypeDecl
			]
			messageStructTypeDef =	messageTypeDecl.createChild(typeDeclaration_TypeDefinition, structTypeSpecification) as StructTypeSpecification
			messageEvent = messageStructTypeDef.createChild(structTypeSpecification_Declaration, dataVariableDeclaration) as DataVariableDeclaration
			messageEvent.createTypeAndVariable(target.getInt, "event")
			messageValue = messageStructTypeDef.createChild(structTypeSpecification_Declaration, dataVariableDeclaration) as DataVariableDeclaration
			messageValue.createTypeAndVariable(target.getInt, "value")
		}
	}
	
	/**
	 * Creates a boolean variable that shows whether a cycle is in progress or a cycle ended.
	 */
	private def createIsStableVar() {		
		isStableVar = target.globalDeclarations.createVariable(DataVariablePrefix.NONE, target.bool, isStableVariableName)
		isStableVar.initVar(false)
	}
	
	/**
	 * Creates an integer variable that stores the id of a particular transition.
	 */
	private def createTransitionIdVar() {		
		transitionIdVar = target.globalDeclarations.createVariable(DataVariablePrefix.NONE, target.int, transitionIdVariableName)
		transitionIdVar.variable.head.createChild(variable_Initializer, expressionInitializer) as ExpressionInitializer => [
			it.createChild(expressionInitializer_Expression, literalExpression) as LiteralExpression => [
				it.text = "-1"
			]
		]
	}
	
	/**
	 * Initializes a bool variable with the given boolean value.
	 */
	private def initVar(DataVariableDeclaration variable, boolean isTrue) {		
		variable.variable.head.createChild(variable_Initializer, expressionInitializer) as ExpressionInitializer => [
			it.createChild(expressionInitializer_Expression, literalExpression) as LiteralExpression => [
				it.text = isTrue.toString
			]
		]
	}
	
	/**
	 * Creates a bool noInnerEvents function that shows whether there are unprocessed events in the queues of the automata.
	 */
	private def createNoInnerEventsFunction() {		
		target.globalDeclarations.createChild(declarations_Declaration, functionDeclaration) as FunctionDeclaration => [
			it.createChild(functionDeclaration_Function, declPackage.function) as Function => [
				it.createChild(function_ReturnType, typeReference) as TypeReference => [
					it.referredType = target.bool
				]
				it.name = "noInnerEvents"
				it.createChild(function_Block, stmPackage.block) as Block => [
					var tempId = 0
					// The declaration is a unique object, it has to be initialized
					it.createChild(block_Declarations, localDeclarations)
					var isFirst = true
					var DataVariableDeclaration lastTempVal
					for (match : InputInstanceEvents.Matcher.on(engine).getAllMatches(null, null, null)) {								
						if (isFirst) {
							val tempVar = it.declarations.createVariable(DataVariablePrefix.NONE, target.bool, "tempVar" + tempId++)
							it.createChild(block_Statement, expressionStatement) as ExpressionStatement => [
								it.createAssignmentExpression(expressionStatement_Expression, tempVar, match.event.getToRaiseVariable(match.port, match.instance))
							]
							lastTempVal = tempVar
							isFirst = false
						}
						//tempVarN = tempVar(N-1) || nextSignalFlag 
						else {
							val lhs = lastTempVal
							val tempVar = it.declarations.createVariable(DataVariablePrefix.NONE, target.bool,  "tempVar" + tempId++)
							it.createChild(block_Statement, expressionStatement) as ExpressionStatement => [
								it.createAssignmentLogicalExpression(expressionStatement_Expression, tempVar, lhs, match.event.getToRaiseVariable(match.port, match.instance))
							]
							lastTempVal = tempVar
						}
					}
					// Return statement
					val returnVal = lastTempVal
					it.createChild(block_Statement, stmPackage.returnStatement) as ReturnStatement => [
						if (returnVal  === null) {
							it.createChild(returnStatement_ReturnExpression, literalExpression) as LiteralExpression => [
								it.text = "true"
							]
						}
						else {
							it.createChild(returnStatement_ReturnExpression, negationExpression) as NegationExpression => [
								it.createChild(negationExpression_NegatedExpression, identifierExpression) as IdentifierExpression => [
									it.identifier = returnVal.variable.head
								]
							]
						}
					]
				]
			]
		]
	}
	
	/**
	 * This rule is responsible for transforming the input signals.
	 * It depends on initNTA.
	 */
	val inputEventsRule = createRule(InputInstanceEvents.instance).action [
		if (!it.instance.isCascade) {
			// Cascade components do not have a double event queue
			val toRaise = target.globalDeclarations.createVariable(DataVariablePrefix.NONE, target.bool, it.event.toRaiseName(it.port, it.instance))
			addToTrace(it.event, #{toRaise}, trace)
			addToTrace(it.instance, #{toRaise}, instanceTrace)
			addToTrace(it.port, #{toRaise}, portTrace)
		}
		val isRaised = target.globalDeclarations.createVariable(DataVariablePrefix.NONE, target.bool, it.event.isRaisedName(it.port, it.instance))
		addToTrace(it.event, #{isRaised}, trace)
		// Saving the owner
		addToTrace(it.instance, #{isRaised}, instanceTrace)
		// Saving the port
		addToTrace(it.port, #{isRaised}, portTrace)
	].build	
	
	 /**
	 * This rule is responsible for transforming the output signals led out to the system interface.
	 * It depends on initNTA.
	 */
	val syncSystemOutputEventsRule = createRule(TopSyncSystemOutEvents.instance).action [
		val boolFlag = target.globalDeclarations.createVariable(DataVariablePrefix.NONE, target.bool, it.event.getOutEventName(it.port, it.instance))
		addToTrace(it.event, #{boolFlag}, trace)
		log(Level.INFO, "Information: System out event: " + it.instance.name + "." + boolFlag.variable.head.name)
		// Maybe the owner setting is not needed?
		val instance = it.instance
		addToTrace(instance, #{boolFlag}, instanceTrace)
		// Saving the port
		addToTrace(it.port, #{boolFlag}, portTrace)
	].build
	
	/**
	 * This rule is responsible for connecting the parameters of actions and triggers to the parameters of events.
	 * It depends on initNTA.
	 */
	val eventParametersRule = createRule(ParameteredEvents.instance).action [
		if (it.event.parameterDeclarations.size != 1) {
			throw new IllegalArgumentException("The event has more than one parameters." + it.event)
		}
		// We deal with already transformed instance events
		val uppaalEvents = it.event.allValuesOfTo.filter(DataVariableDeclaration)
							.filter[!it.variable.head.name.startsWith("toRaise")] // So we give one parameter to in events and out events too
		for (uppaalEvent : uppaalEvents) {
			val owner = uppaalEvent.owner
			val port = uppaalEvent.port
			val eventValue = it.param.transformVariable(it.param.type, DataVariablePrefix.NONE,
				uppaalEvent.variable.head.valueOfName)
			// Parameter is now not connected to the Event
			addToTrace(it.param, #{eventValue}, trace) // Connected to the port through name (getValueOfName - bad convention)
			addToTrace(owner, #{eventValue}, instanceTrace)
			addToTrace(port, #{eventValue}, portTrace)
		}
	].build
	
	
	/**
	 * This rule is responsible for transforming the variables.
	 * It depends on initNTA.
	 */
	val variablesRule = createRule(InstanceVariables.instance).action [
		val variable = it.variable.transformVariable(it.variable.type, DataVariablePrefix.NONE,
			it.variable.name + "Of" + instance.name)
		addToTrace(it.instance, #{variable}, instanceTrace)		
		// Traces are created in the transformVariable method
	].build
	
	/**
	 * This rule is responsible for transforming the constants.
	 * It depends on initNTA.
	 */
	val constantsRule = createRule(ConstantDeclarations.instance).action [
		it.constant.transformVariable(it.type, DataVariablePrefix.CONST, 
			it.constant.name + "Of" + (it.constant.eContainer as Package).name)
		// Traces are created in the createVariable method
	].build
	
	/**
	 * This rule is responsible for transforming the initializations of declarations.
	 * It depends on variablesRule and constantsRule.
	 */
	val declarationInitRule = createRule(DeclarationInitializations.instance).action [
		val initExpression = it.initValue
		for (uDeclaration : it.declaration.allValuesOfTo.filter(DataVariableDeclaration)) {
			var ComponentInstance owner = null
			if (uDeclaration.prefix != DataVariablePrefix.CONST) {
				owner = uDeclaration.owner
			}
			val finalOwner = owner 
			uDeclaration.variable.head.createChild(variable_Initializer, expressionInitializer) as ExpressionInitializer => [
				it.transform(expressionInitializer_Expression, initExpression, finalOwner)
			]		
		}
		// Traces are created in the transformVariable method
	].build
	
	private def transformTopComponentArguments() {
		for (var i = 0; i < topComponentArguments.size; i++) {
			val parameter = component.parameterDeclarations.get(i)
			val argument = topComponentArguments.get(i)
			val initializer = createExpressionInitializer => [
				it.transform(expressionInitializer_Expression, argument, null /*No instance associated*/)
			]
			// The initialization is created, variable has to be created
			val uppaalVariable = parameter.transformVariable(parameter.type, DataVariablePrefix.CONST,
				parameter.name + "Of" + component.name)
			uppaalVariable.variable.head.initializer = initializer
			// Traces are created in the createVariable method
		}
	}
	
	/**
	 * This rule is responsible for transforming the bound parameters.
	 * It depends on initNTA.
	 */
	val parametersRule = createRule(ParameterizedInstances.instance).action [
		val instance = it.instance
		val parameters = instance.derivedType.parameterDeclarations
		val arguments = instance.arguments
		checkState(parameters.size == arguments.size)
		for (var i = 0; i < parameters.size; i++) {
			val parameter = parameters.get(i)
			val argument = arguments.get(i)
			try {
				/* Trying to create the initialization based on the argument
					(succeeds if all referred parameters are already mapped) */
				val initializer = createExpressionInitializer => [
					it.transform(expressionInitializer_Expression, argument, instance)
				]
				// The initialization is created, variable has to be created
				val uppaalVariable = parameter.transformVariable(parameter.type, DataVariablePrefix.CONST,
					parameter.name + "Of" + instance.name)
				uppaalVariable.variable.head.initializer = initializer
			} catch (Exception exception) {
				// An argument refers to a not yet mapped parameter
				// Waiting for next turn
			}
		}
		// Traces are created in the createVariable method
	].build
	
	private def areAllParametersTransformed() {
		return ParameterizedInstances.Matcher.on(engine).allMatches
				.forall[it.instance.areAllArgumentsTransformed]
	}

	private def areAllArgumentsTransformed(ComponentInstance instance) {
		return instance.derivedType.parameterDeclarations.forall[it.traced]
	}
	
	/**
	 * This rule is responsible for transforming all regions to templates. (Top regions and subregions.)
	 * It depends on initNTA.
	 */
	val regionsRule = createRule(InstanceRegions.instance).action [
		val instance = it.instance
		val name = it.region.regionName
		val template = target.createChild(getNTA_Template, template) as Template => [
			it.name = name + "Of" + instance.name
		]
		// Creating the local declaration container of the template
		val localDeclaration = template.createChild(template_Declarations, localDeclarations) as LocalDeclarations
		if (it.region.subregion) {
			val isActiveVar = localDeclaration.createVariable(DataVariablePrefix.NONE, target.bool, "isActive")
			addToTrace(it.region, #{isActiveVar}, trace)
			addToTrace(instance, #{isActiveVar}, instanceTrace)
		}
		// Creating the runCycle sync var
		val runCycleVar = target.globalDeclarations.createSynchronization(true, false, "runCycle" + template.name.toFirstUpper)
		addToTrace(template, #{runCycleVar}, trace)
		addToTrace(instance, #{runCycleVar}, instanceTrace)
		// Creating the isScheduled sync var
		val isScheduledVar = target.globalDeclarations.createVariable(DataVariablePrefix.NONE, target.bool, "isScheduled" + name + "Of" + instance.name)
		addToTrace(template, #{isScheduledVar}, trace)
		addToTrace(instance, #{isScheduledVar}, instanceTrace)
		// Creating the trace
		addToTrace(it.region, #{template}, trace)
		addToTrace(instance, #{template}, instanceTrace)
	].build
	
	/**
	 * This rule is responsible for transforming the entry states to committed locations.
	 * If the parent regions is a subregion, a new init location is generated as well.
	 * It depends on regionsRule.
	 */
	val entriesRule = createRule(Entries.instance).action [
		for (template : it.region.getAllValuesOfTo.filter(Template)) {
			val owner = template.owner
			val initLocation = template.createChild(template_Location, location) as Location => [
				it.name = "EntryLocation" + id++
				it.locationTimeKind = LocationKind.COMMITED			
				it.comment = "Entry Location"
			]
			// If it is a subregion, a new location is generated and set initial
			if (it.region.subregion) {
				val generatedInitLocation = template.createChild(template_Location, location) as Location => [
					it.name = "GenInitLocation" + id++
					it.comment = "Generated for the synchronization of subregions."
				]	
				template.init = generatedInitLocation			
				// Putting the generated init next to the committed
				addToTrace(it.entry, #{generatedInitLocation}, trace)				
				addToTrace(owner, #{generatedInitLocation}, instanceTrace)
			}
			else {
				template.init = initLocation
			}
			// Creating the trace
			addToTrace(it.entry, #{initLocation}, trace)
			addToTrace(owner, #{initLocation}, instanceTrace)
		}
	].build
	
	/**
	 * This rule is responsible for transforming all states to committed location -> edge -> locations.
	 * (The edge is there for the subregion synchronization and entry event assignment.)
	 * It depends on regionsRule.
	 */
	val statesRule = createRule(States.instance).action [
		val gammaState = it.state
		for (template : it.region.getAllValuesOfTo.filter(Template)) {
			val owner = template.owner
			val stateLocation = template.createChild(template_Location, location) as Location => [
				it.name = gammaState.locationName
			]		
			val entryLocation = template.createChild(template_Location, location) as Location => [
				it.name = gammaState.entryLocationNameOfState 
				it.locationTimeKind = LocationKind.COMMITED	
				it.comment = "Pseudo state for subregion synchronization"
			]
			val entryEdge = entryLocation.createEdge(stateLocation)
			entryEdge.comment = "Edge for subregion synchronization"
			// Creating the trace
			addToTrace(gammaState, #{entryLocation, entryEdge, stateLocation}, trace)
			addToTrace(owner, #{entryLocation, entryEdge, stateLocation}, instanceTrace)
		}
	].build
	
	/**
	 * This rule is responsible for transforming all choices to committed locations.
	 * It depends on regionsRule.
	 */
	val choicesRule = createRule(ChoicesAndMerges.instance).action [
		for (template : it.region.getAllValuesOfTo.filter(Template)) {
			val owner = template.owner
			val choiceLocation = template.createChild(template_Location, location) as Location => [
				it.name = "Choice" + id++
				it.locationTimeKind = LocationKind.COMMITED	
				it.comment = "Choice"
			]
			// Creating the trace
			addToTrace(it.pseudoState, #{choiceLocation}, trace)
			addToTrace(owner, #{choiceLocation}, instanceTrace)		
		}
	].build
	
	/**
	 * This rule is responsible for transforming all same region transitions (whose sources and targets are in the same region) to edges.
	 * It depends on all the rules that create nodes.
	 */
	val sameRegionTransitionsRule = createRule(SameRegionTransitions.instance).action [
		for (template : it.region.allValuesOfTo.filter(Template)) {
			val owner = template.owner
			val source = getEdgeSource(it.source).filter(Location).filter[it.parentTemplate == template].head
			val target = getEdgeTarget(it.target).filter(Location).filter[it.parentTemplate == template].head
			val edge = source.createEdge(target)
			// Updating the scheduling variable
			edge.setIsScheduledVar
			// Creating the trace
			addToTrace(it.transition, #{edge}, trace)		
			addToTrace(owner, #{edge}, instanceTrace)		
			// For test generation (after adding owner)
			edge.generateTransitionId
		}
	].build
	
	private def setIsScheduledVar(Edge edge) {
		val template = edge.parentTemplate
		val isScheduledVars = template.allValuesOfTo.filter(DataVariableDeclaration)
		checkState(isScheduledVars.size == 1)
		val isScheduledVar = isScheduledVars.head
		edge.createAssignmentExpression(edge_Update, isScheduledVar, true)
	}
	
	private def generateTransitionId(Edge edge) {
		val owner = edge.owner as SynchronousComponentInstance
		// testedComponentsForTransitions stores the instances to which tests need to be generated
		if (testedComponentsForTransitions.exists[it.contains(owner)] &&
				edge.source.allValuesOfFrom.filter(EntryState).empty /*No initial edges*/) {
			edge.createAssignmentExpression(edge_Update, transitionIdVar,
				createLiteralExpression => [it.text = (transitionId++).toString]
			)
		}
	}
	
	/**
	 * This rule is responsible for transforming transitions whose targets are in a lower abstraction level (lower region)
	 * than its source.
	 */
	val toLowerRegionTransitionsRule = createRule(ToLowerInstanceTransitions.instance).action [		
		val syncVar = target.globalDeclarations.createSynchronization(true, false, acrossRegionSyncNamePrefix + id++)
		it.transition.toLowerTransitionRule(it.source, it.target, new HashSet<Region>(), syncVar, it.target.levelOfStateNode, it.instance)		
	].build
	
	/**
	 * Responsible for transforming a transition whose target is in a lower abstraction level (lower region)
	 * than its source.
	 */
	private def void toLowerTransitionRule(Transition transition, StateNode tsource, StateNode ttarget, Set<Region> visitedRegions, 
			ChannelVariableDeclaration syncVar, int lastLevel, SynchronousComponentInstance owner) {
		// Going back to top level
		if (tsource.eContainer != ttarget.eContainer) {
			visitedRegions.add(ttarget.eContainer as Region)
			transition.toLowerTransitionRule(tsource, ttarget.eContainer.eContainer as StateNode, visitedRegions, syncVar, lastLevel, owner)
		}
		// On top level
		if (tsource.eContainer == ttarget.eContainer) {
			val targetLoc = ttarget.allValuesOfTo.filter(Location).filter[it.locationTimeKind == LocationKind.NORMAL].filter[it.owner == owner].head 
			val sourceLoc = tsource.allValuesOfTo.filter(Location).filter[it.locationTimeKind == LocationKind.NORMAL].filter[it.owner == owner].head
			val toLowerEdge = sourceLoc.createEdge(targetLoc)		
			// Updating the scheduling variable upon firing
			toLowerEdge.setIsScheduledVar
			addToTrace(transition, #{toLowerEdge}, trace)
			addToTrace(owner, #{toLowerEdge}, instanceTrace)
			// For test generation (after adding owner)
			toLowerEdge.generateTransitionId
			// Creating the sync edge
			val syncEdge = createCommittedSyncTarget(targetLoc, syncVar.variable.head, "AcrossEntry" + id++)
			toLowerEdge.setTarget(syncEdge.source)
			// Entry events must NOT be done here as they have to be after exit events and regular assignments!	
			// All the orthogonal regions except for the visited one have to be set to the right state
			(ttarget as State).regions.setSubregions(visitedRegions, syncVar, true, owner)
			// If the source is a composite state, its subregions must be deactivated
			if (tsource instanceof State) {
				tsource.allRegions.setSubregions(emptySet, syncVar, false, owner)
			}
		}
		else {
			val region = ttarget.eContainer as Region
			var Location targetLoc 
			// If it is an intermediate region, the normal location is the target
			if (lastLevel != ttarget.levelOfStateNode) {
				targetLoc = ttarget.allValuesOfTo.filter(Location).filter[it.locationTimeKind == LocationKind.NORMAL].filter[it.owner == owner].head
				// The orthogonal regions of the composite states have to be activated
				if (ttarget.composite) {			
					(ttarget as State).regions.setSubregions(visitedRegions, syncVar, true, owner)
				}
			}
			// On the last level the ordinary target location of the state is the target
			else {
				targetLoc = ttarget.edgeTarget.filter[it.owner == owner].head
			}
			val template = ttarget.eContainer.allValuesOfTo.filter(Template).filter[it.owner == owner].head		
			val locations = new HashSet<Location>(template.location) // To avoid ConcurrentModification
			for (location : locations.filter[it.locationTimeKind != LocationKind.COMMITED]) {				
				// Creating a sync edge and placing a synchronization onto it
				val activationEdge = location.createEdgeWithSync(targetLoc, syncVar.variable.head, SynchronizationKind.RECEIVE)
				// Creating an update so it activates the template
				activationEdge.setTemplateActivation(region, true)
				// If this is not the last level, all the entry events have to be created
				if (lastLevel != ttarget.levelOfStateNode) {
					activationEdge.setEntryEvents(ttarget as State, owner)
				}
			}
		}
	}
	
	/**
	 * Responsible for placing entry events onto edges that go lower templates.
	 * Depends on assignmentActionsRule.
	 */
	val toLowerRegionEntryEventTransitionsRule = createRule(ToLowerInstanceTransitions.instance).action [		
		transition.toLowerTransitionRuleEntryEvent(it.source, it.target, it.instance)
	].build
	
	private def void toLowerTransitionRuleEntryEvent(Transition transition, StateNode tsource, StateNode ttarget, SynchronousComponentInstance owner) {
		// Going back to top level
		if (tsource.eContainer != ttarget.eContainer) {
			transition.toLowerTransitionRuleEntryEvent(tsource, ttarget.eContainer.eContainer as StateNode, owner)
		}
		// On top level
		if (tsource.eContainer == ttarget.eContainer) {
			for (toLowerEdge : transition.allValuesOfTo.filter(Edge).filter[it.owner == owner]) {
				toLowerEdge.setEntryEvents(ttarget as State, owner)	
			}					
		}		
	}
	
	/**
	 * Responsible for putting all the entry updates and signal raising of a given state onto the given edge.
	 */
	private def setEntryEvents(Edge edge, State state, SynchronousComponentInstance owner) {
		// Entry event updates
		for (assignmentAction : state.entryActions.filter(AssignmentStatement)) {
			edge.transformAssignmentAction(edge_Update, assignmentAction, owner)
		}
		// Entry event event raising
		for (match : RaiseInstanceEventStateEntryActions.Matcher.on(engine).getAllMatches(state, null, owner, null, null, null, null)) {
			edge.createEventRaising(match.inPort, match.raisedEvent, match.inInstance, match.entryAction)
		}
		for (match : RaiseTopSystemEventStateEntryActions.Matcher.on(engine).getAllMatches(null, state, owner, null, null, null)) {
			edge.createEventRaising(match.outPort, match.raisedEvent, match.instance, match.entryAction)
		}
	}
	
	/**
	 * Responsible for enabling/disabling the regions of the given state except for the regions given in visitedRegions.
	 */
	private def setSubregions(Collection<Region> regions, Set<Region> visitedRegions, ChannelVariableDeclaration syncVar, boolean enter, SynchronousComponentInstance owner) {
		val regionsToSet = new HashSet<Region>(regions)
		regionsToSet.removeAll(visitedRegions)
		regionsToSet.forEach[it.synchronizeSubregion(syncVar, enter, owner)]	
	}
	
	/**
	 * Returns the number of parent regions of a stateNode.
	 */
	private def int getLevelOfStateNode(StateNode stateNode) {
		if ((stateNode.eContainer as Region).isTopRegion) {
			return 1
		}
		else {
			getLevelOfStateNode(stateNode.eContainer.eContainer as State) + 1
		}
	}
	
	/**
	 * This rule is responsible for transforming transitions whose targets are in a higher abstraction level (higher region)
	 * than its source.
	 */
	val toHigherRegionTransitionsRule = createRule(ToHigherInstanceTransitions.instance).action [		
		val syncVar = target.globalDeclarations.createSynchronization(true, false, acrossRegionSyncNamePrefix + id++)
		it.transition.toHigherTransitionRule(it.source, it.target, new HashSet<Region>(), syncVar, it.source.levelOfStateNode, it.instance)
	].build
	
	/**
	 * This rule is responsible for transforming a transition whose targets are in a higher abstraction level (higher region)
	 * than its source.
	 */
	private def void toHigherTransitionRule(Transition transition, StateNode tsource, StateNode ttarget, Set<Region> visitedRegions, ChannelVariableDeclaration syncVar, int lastLevel, SynchronousComponentInstance owner) {
		// Lowest level
		if (tsource.levelOfStateNode == lastLevel) {
			val region = tsource.eContainer as Region
			visitedRegions.add(region)
			val sourceLoc = tsource.allValuesOfTo.filter(Location).filter[it.locationTimeKind == LocationKind.NORMAL].filter[it.owner == owner].head	
			// Creating a the transition equivalent edge
			val toHigherEdge = sourceLoc.createEdge(sourceLoc)		
			// Setting isScheduled variable to true upon firing 
			toHigherEdge.setIsScheduledVar
			addToTrace(transition, #{toHigherEdge}, trace)
			addToTrace(owner, #{toHigherEdge}, instanceTrace)
			// For test generation (after adding owner)
			toHigherEdge.generateTransitionId
			// Getting the target of the deactivating edge
			val targetLoc = region.getDeactivatingEdgeTarget(sourceLoc)
			// This plus sync edge will contain the deactivation (so triggers can be put onto the original one)
			val syncEdge = createCommittedSyncTarget(targetLoc, syncVar.variable.head, "AcrossEntry" + id++)
			toHigherEdge.target = syncEdge.source			
			syncEdge.setTemplateActivation(region, false)
			// No need to set the exit events, since exitAssignmentActionsOfStatesRule and exitEventRaisingActionsOfStatesRule do that
			transition.toHigherTransitionRule(tsource.eContainer.eContainer as State, ttarget, visitedRegions, syncVar, lastLevel, owner)			
		}
		// Highest level
		else if (tsource.levelOfStateNode == ttarget.levelOfStateNode) {
			visitedRegions.add(tsource.eContainer as Region)
			val sourceLoc = tsource.allValuesOfTo.filter(Location).filter[it.locationTimeKind == LocationKind.NORMAL].filter[it.owner == owner].head
			val targetLoc = getEdgeTarget(ttarget).filter[it.owner == owner].head
			// Sync edge on the highest level with exit events
			val syncEdge = createEdgeWithSync(sourceLoc, targetLoc, syncVar.variable.head, SynchronizationKind.RECEIVE)			
			syncEdge.setExitEvents(tsource as State, owner)
			// Setting the regular assignments of the transition, so it takes place after the exit events
			for (assignment : transition.effects.filter(AssignmentStatement)) {
				syncEdge.transformAssignmentAction(edge_Update, assignment, owner)				
			}	
			// The event raising of the transition is done here, though the order of event raising does not really matter in this transformer
			for (raiseEventAction : transition.effects.filter(RaiseEventAction)) {
				for (match : RaiseInstanceEventOfTransitions.Matcher.on(engine).getAllMatches(transition, raiseEventAction, owner, raiseEventAction.port, null, null, null)) {
					syncEdge.createEventRaising(match.inPort, match.raisedEvent, match.inInstance, match.eventRaiseAction)
				}
			}		
			val allSubRegions = AllSubregionsOfCompositeStates.Matcher.on(engine).getAllValuesOfregion(tsource as State)
			allSubRegions.setSubregions(visitedRegions, syncVar, false, owner)
			// This template is not deactivated since it is the highest level			
		}
		// Intermediate levels
		else {	
			visitedRegions.add(tsource.eContainer as Region)		
			val sourceLoc = tsource.allValuesOfTo.filter(Location).filter[it.locationTimeKind == LocationKind.NORMAL].filter[it.owner == owner].head
			// Loop edge with exit events and deactivation
			val loopEdge = createEdgeWithSync(sourceLoc, sourceLoc, syncVar.variable.head, SynchronizationKind.RECEIVE)
			loopEdge.setExitEvents(tsource as State, owner)
			loopEdge.setTemplateActivation(tsource.eContainer as Region, false)
			transition.toHigherTransitionRule(tsource.eContainer.eContainer as State, ttarget, visitedRegions, syncVar, lastLevel, owner)
		}
	}
	
	/**
	 * Places an "isActive" guard onto the given edge based on the given variable.
	 */
	private def createIsActiveGuard(Edge edge) {
		val parentTemplate = edge.parentTemplate		
		val region = parentTemplate.allValuesOfFrom.filter(Region).head
		// If the region is a top region, no isActive guard is needed
		if (region.isTopRegion) {
			return
		}
		val owner = edge.owner
		val isActiveVar = region.allValuesOfTo.filter(DataVariableDeclaration)
								.filter[it.localVariableToTemplate == edge.parentTemplate && it.owner == owner].head
		edge.addGuard(isActiveVar, LogicalOperator.AND)
	}
	
	/**
	 * This rule is responsible for creating synchronizations in the subregions of composite states
	 * to make sure they get to the proper state at each entry.
	 * It depends on all the rules that create nodes (including timeTriggersRule).
	 */
	val compositeStateEntryRule = createRule(CompositeStates.instance).action [
		for (entryEdge : it.compositeState.allValuesOfTo.filter(Edge)) {
			val owner = entryEdge.owner as SynchronousComponentInstance
			// Creating the synchronization variable
			val syncVar = target.globalDeclarations.createSynchronization(true, false, it.compositeState.entrySyncNameOfCompositeState)			
			addToTrace(owner, #{syncVar}, instanceTrace)	
			// Placing it on the synchronization entry edge
			entryEdge.setSynchronization(syncVar.variable.head, SynchronizationKind.SEND)
			// Synchronizing each template equivalent of the regions of the composite state
			for (subregion : it.compositeState.regions) {
				subregion.synchronizeSubregion(syncVar, true, owner)
			}
			// Creating the trace
			addToTrace(it.compositeState, #{syncVar}, trace)
		}
	].build
	
	/**
	 * Responsible for synchronizing the given subregion (? sync, edges from normal locations to the init/self location).
	 */
	private def synchronizeSubregion(Region subregion, ChannelVariableDeclaration syncVar, boolean enter, SynchronousComponentInstance owner) {
		for (template : subregion.getAllValuesOfTo.filter(Template).filter[it.owner == owner]) {
			// There must be an edge from each location to the entry (no history) or to itself (history)
			val normalLocations = new HashSet<Location>(template.location) // Against concurrentModException			
			for (location : normalLocations.filter[it.locationTimeKind != LocationKind.COMMITED]) {
				createSynchronizationEdge(subregion, location, owner, syncVar, enter)				
			}		
		}
	}
	
	/**
	 * Responsible for creating a synchronization edge that sets the template to the proper state (location and isActive variable).
	 */
	private def createSynchronizationEdge(Region subregion, Location source, SynchronousComponentInstance owner, ChannelVariableDeclaration syncVar, boolean enter) {
		// If the subregion has a history, the target must be different
		var Location target
		// Target depends on entry/exit and if and entry, has history or not
		if (enter) {
			if (subregion.hasHistory) {
				// Target is determined by a dispatch method (because a mapping might have more "outputs")
				target = getEdgeTarget(source.allValuesOfFrom.filter(StateNode).head)
								.filter(Location).filter[it.parentTemplate == source.parentTemplate].head
			}
			// Target is the committed location of the template
			else {
				target = Entries.Matcher.on(engine).getAllValuesOfentry(subregion).filter(EntryState).head.allValuesOfTo
							.filter(Location).filter[it.locationTimeKind == LocationKind.COMMITED].filter[it.parentTemplate == source.parentTemplate].head
			}
		}
		// In case of exit
		else {
			target = subregion.getDeactivatingEdgeTarget(source)
		}
		val realTarget = target
		// Creating an edge with a ? synchronization and an "isActive" update
		val activationEdge = source.createEdge(realTarget)
		// If the state has exit event, it has to placed onto the edge
		if (!enter) {
			if (owner === null) {
				throw new Exception("The given location has no owner: " + location)
			}
			activationEdge.setExitEvents(source.allValuesOfFrom.filter(State).head, owner)
		}
		// Placing a synchronization onto the edge
		activationEdge.setSynchronization(syncVar.variable.head, SynchronizationKind.RECEIVE)
		// Creating an update so it activates/deactivates the template
		activationEdge.setTemplateActivation(subregion, enter)
		if (enter && subregion.hasHistory) {
			// In history scheduling variable setting is needed (if there is no history, the scheduling is done by the initial edge)
			activationEdge.setIsScheduledVar
		}
	}
	
	private def getDeactivatingEdgeTarget(Region region, Location source) {
		// If the region ha history, the target is the source (remembering last active state)
		if (region.hasHistory) {
			return source
		}
		// The target is the inactive location to reduce state space
		else {
			return source.parentTemplate.init
		}
	}
	
	/**
	 * Places the exit actions of the given state onto the given edge. If the given state has no exit action, nothing happens.
	 */
	private def setExitEvents(Edge edge, State state, SynchronousComponentInstance owner) {
		if (state !== null) {
			// Assignment actions
			for (action : state.exitActions.filter(AssignmentStatement)) {
				edge.transformAssignmentAction(edge_Update, action, owner)			
			}		
			// Signal raising actions
			for (match : RaiseInstanceEventStateExitActions.Matcher.on(engine).getAllMatches(state, null, owner, null, null, null, null)) {
				edge.createEventRaising(match.inPort, match.raisedEvent, match.inInstance, match.exitAction)
			}
			for (match : RaiseTopSystemEventStateExitActions.Matcher.on(engine).getAllMatches(null, state, owner, null, null, null)) {
				edge.createEventRaising(match.outPort, match.raisedEvent, match.instance, match.exitAction)
			}
		}
	}
	
	/**
	 * Responsible for placing an activation assignment onto the given edge: "isActive = true/false".
	 */
	private def setTemplateActivation(Edge edge, Region subregion, boolean enter) {
		edge.createChild(edge_Update, assignmentExpression) as AssignmentExpression => [
			it.createChild(binaryExpression_FirstExpr, identifierExpression) as IdentifierExpression => [
				it.identifier = subregion.allValuesOfTo.filter(VariableDeclaration).filter[it.localVariableToTemplate == edge.parentTemplate].head.variable.head // Using only one variable in each declaration
			]
			it.operator = AssignmentOperator.EQUAL
			it.createChild(binaryExpression_SecondExpr, literalExpression) as LiteralExpression => [
				it.text = enter.toString
			]
		]
	}	
	
	/**
	 * Returns the template that contains the given variable.
	 */
	private def Template localVariableToTemplate(VariableDeclaration variable) {
		return variable.eContainer.eContainer as Template
	}
	
	/**
	 * This rule is responsible for creating synchronizations in the subregions of composite states and exit transitions
	 * to make sure templates are deactivated at each exit.
	 * It depends on all the rules that create nodes and edges.
	 */
	private def compositeStateExitRule() {
		for (compositeState : OutgoingTransitionsOfCompositeStates.Matcher.on(engine).allValuesOfcompositeState) {
			// Iterating through all the instances that have the mapping of this particular composite state (compositeState)
			// A state may be mapped to more NORMAL locations thanks to timing (timer_id locations), so a set of owners is needed
			for (owner : compositeState.allValuesOfTo.filter(Location).filter[it.locationTimeKind == LocationKind.NORMAL].map[it.owner].toSet) {
				// Creating the synchronization variable
				val syncVar = target.globalDeclarations.createSynchronization(true, false, compositeState.exitSyncNameOfCompositeState) 
				// Synchronizing each template equivalent of the regions of the composite state
				for (subregion : AllSubregionsOfCompositeStates.Matcher.on(engine).getAllValuesOfregion(compositeState)) {
					val template = subregion.getAllValuesOfTo.filter(Template).filter[it.owner == owner].head
					// There must be an edge from each location to itself
					val normalLocations = new HashSet<Location>(template.location)
					for (location : normalLocations.filter[it.locationTimeKind != LocationKind.COMMITED]) {
						createSynchronizationEdge(subregion, location, owner as SynchronousComponentInstance, syncVar, false) 				
					}	
				}
				for (outgoingTransition : OutgoingTransitionsOfCompositeStates.Matcher.on(engine).getAllValuesOfoutgoingTransition(compositeState, null)
																					.filter[it.sourceState.eContainer == it.targetState.eContainer]) {
					val originalExitEdge = outgoingTransition.allValuesOfTo.filter(Edge).filter[it.owner == owner].head
					// Only same region transitions are handled this way
					val originalTarget = originalExitEdge.target
					// Creating a new sync edge with the syncVar above
					val newSyncEdge = originalTarget.createCommittedSyncTarget(syncVar.variable.head, compositeState.exitLocationNameOfCompositeState)
					// Setting the target of the original edge to the recently created committed location
					originalExitEdge.target = newSyncEdge.source
					// Resetting the exit events so these events are executed after the exit events of child states
					if (!compositeState.exitActions.empty) {
						val newExitEventEdge = originalTarget.createEdgeCommittedTarget("NewExitEventUpdateOf" + compositeState.name) => [
							it.update += originalExitEdge.update
						]
						newSyncEdge.target = newExitEventEdge.source
					}
				}
				// Creating the trace
				addToTrace(compositeState, #{syncVar}, trace)
				addToTrace(owner, #{syncVar}, instanceTrace)			
			}
		}			
	}	
	
	/**
	 * This rule is responsible for transforming the event triggers.
	 * It depends on eventsRule and sameRegionTransitionsRule.
	 */
	val eventTriggersRule = createRule(EventTriggersOfTransitions.instance).action [
		for (edge : it.transition.allValuesOfTo.filter(Edge)) {
			checkState(edge.guard === null) // Must this assert be true at all times?
			val owner = edge.owner
			val triggerGuard = it.trigger.transformTrigger(owner)
			if (edge.guard === null) {
				edge.guard = triggerGuard
			}
//			else {
//				edge.guard = channelVar.createLogicalExpression(LogicalOperator.OR, edge.guard)
//			}
			edge.setRunCycle
			// Creating the trace
			addToTrace(it.trigger, #{triggerGuard}, trace)		
		}
	].build
	
	/**
	 * Places a runCycle synchronization onto the given edge.
	 */
	private def void setRunCycle(Edge edge) {
		val parentTemplate = edge.parentTemplate
		val runCycleVar = parentTemplate.allValuesOfTo.filter(ChannelVariableDeclaration).head // Only one channel per instance
		if (edge.synchronization !== null && edge.synchronization.channelExpression.identifier == runCycleVar.variable.head) {
			return
		}
		if (edge.synchronization !== null) {
			throw new IllegalArgumentException("The given edge already contains a synchronization: " + edge.source + "\n" + edge.target)
		}
		edge.setSynchronization(runCycleVar.variable.head, SynchronizationKind.RECEIVE)
	}
	
	/**
	 * This rule is responsible for transforming the timeout event triggers.
	 * It depends on sameRegionTransitionsRule, toLowerTransitionsRule, ToHigherTransitionsRule and triggersRule.
	 */
	val timeTriggersRule = createRule(TimeTriggersOfTransitions.instance).action [
		for (edge : it.transition.allValuesOfTo.filter(Edge)) {
			val owner = edge.owner
			var Edge cloneEdge
			// This rule comes right after the signal trigger rule
			if (edge.guard !== null) {
				// If it contains a guard, it contains a trigger, and the signals are in an OR relationship
				cloneEdge = edge.clone as Edge
				cloneEdge.guard.removeTrace
				cloneEdge.guard = null
				addToTrace(owner, #{cloneEdge}, instanceTrace)
			}
			else {
				cloneEdge = edge
			}
			val template = cloneEdge.parentTemplate
			var clockVar = it.state.stateClock
			// Creating the trace
			addToTrace(it.timeoutDeclaration, #{clockVar}, trace)
			addToTrace(owner, #{clockVar}, instanceTrace)
			val location = cloneEdge.source
			val locInvariant = location.invariant
			val newLoc = template.createChild(template_Location, getLocation) as Location => [
				it.name = clockNamePrefix + (id++)
			]
			// Creating the trace; this is why this rule depends on toLowerTransitionsRule and ToHigherTransitionsRule
			addToTrace(it.state, #{newLoc}, trace)
			addToTrace(owner, #{newLoc}, instanceTrace)			
			val newEdge = location.createEdge(newLoc)
			cloneEdge.source = newLoc
			cloneEdge.setRunCycle
			// Creating the owner trace for the clock edge
			addToTrace(owner, #{newEdge}, instanceTrace)
			// Converting to milliseconds
			val timeValue = it.time.convertToMs
			// Putting the expression onto the location and edge
			if (locInvariant !== null) {
				location.insertLogicalExpression(location_Invariant, CompareOperator.LESS_OR_EQUAL, clockVar, timeValue, locInvariant, it.timeoutEventReference, LogicalOperator.AND)
			}
			else {
				location.insertCompareExpression(location_Invariant, CompareOperator.LESS_OR_EQUAL, clockVar, timeValue, it.timeoutEventReference)
			}
			val originalGuard = cloneEdge.guard
			if (originalGuard !== null) {
				newEdge.insertLogicalExpression(edge_Guard, CompareOperator.GREATER_OR_EQUAL, clockVar, timeValue, originalGuard, it.timeoutEventReference, LogicalOperator.OR)		
			}
			else {
				newEdge.insertCompareExpression(edge_Guard, CompareOperator.GREATER_OR_EQUAL, clockVar, timeValue, it.timeoutEventReference)		
			}		
			// Trace is created in the insertCompareExpression method
			// Adding isStable guard
			newEdge.addGuard(isStableVar, LogicalOperator.AND)
		}	
	].build
	
	protected def getStateClock(State state) {
		val template = state.allValuesOfTo.filter(Location).head.parentTemplate
		// The idea is that a template needs a single clock if every state has a single timer
		val clocks = template.declarations.declaration.filter(ClockVariableDeclaration)
		var ClockVariableDeclaration clockVar
		if (clocks.empty || TimeTriggersOfTransitions.Matcher.on(engine)
				.getAllValuesOftimeoutDeclaration(state, null, null, null, null).size > 1) {
			// If the template has no clocks OR the state has more than one timer, a NEW clock has to be created
			clockVar = template.declarations.createChild(declarations_Declaration, clockVariableDeclaration) as ClockVariableDeclaration
			clockVar.createTypeAndVariable(target.clock, clockNamePrefix + (id++))
			return clockVar
		}
		// The simple common template clock is enough
		return clocks.head
	}
	
	protected def extendTimedLocations() {
		val timedEdges = EdgesWithClock.Matcher.on(ViatraQueryEngine.on(new EMFScope(target))).allValuesOfedge
		for (timedEdge : timedEdges) {
			val parentTemplate = timedEdge.parentTemplate
			val timedLocation = timedEdge.source
			val outgoingEdges = newHashSet
			outgoingEdges += parentTemplate.edge.filter[it.source === timedLocation && // Edges going out from the original location
				!timedEdges.contains(it) && // No timed edges
				!(it.synchronization !== null && // No entry and exit synch edges, as they are present in the target too
					(it.synchronization.channelExpression.identifier.name.startsWith(Namings.entrySyncNamePrefix) ||
						it.synchronization.channelExpression.identifier.name.startsWith(Namings.exitSyncNamePrefix)
					)
				)
			]
			val targetLocation = timedEdge.target
			for (outgoingEdge : outgoingEdges) {
				// Cloning all outgoing edges of original location
				val clonedOutgoingEdge = outgoingEdge.clone as Edge
				clonedOutgoingEdge.source = targetLocation
				val targetOutgoingEdges = newHashSet
				targetOutgoingEdges += parentTemplate.edge.filter[it.source === targetLocation && it !== clonedOutgoingEdge]
				var isDuplicate = false
				// Deleting the cloned edge if we find out it is a duplicate (maybe it is not needed anymore)
				for (targetOutgoingEdge : targetOutgoingEdges) {
					if (!isDuplicate && clonedOutgoingEdge.helperEquals(targetOutgoingEdge)) {
						clonedOutgoingEdge.delete
						isDuplicate = true
					}
				}
			}
		}
	}
	
	/**
	 * This rule is responsible for transforming the guards.
	 * It depends on sameRegionTransitionsRule, eventTriggersRule, timeTriggersRule and ExpressionTransformer.
	 */
	val guardsRule = createRule(GuardsOfTransitions.instance).action [
		for (edge : it.transition.allValuesOfTo.filter(Edge)) {
			edge.transformGuard(it.guard)		
		}
		// The trace is created by the ExpressionTransformer
	].build
	
	/**
	 * Responsible for placing the Gamma expressions onto the given edge. It is needed to ensure that "isActive"
	 * variables are handled correctly (if they are present).
	 */
	private def transformGuard(Edge edge, hu.bme.mit.gamma.expression.model.Expression guard) {
		// If the reference is not null there are "triggers" on it
		if (edge.guard !== null) {
			// Getting the old reference
			val oldGuard = edge.guard as Expression
			// Creating the new andExpression that will contain the same reference and the regular guard expression
			val andExpression = edge.createChild(edge_Guard, logicalExpression) as LogicalExpression => [
				it.operator = LogicalOperator.AND
				it.secondExpr = oldGuard
			]		
			// This is the transformation of the regular Gamma guard
			andExpression.transform(binaryExpression_FirstExpr, guard, edge.owner)
		}
		// If there is no "isActive" reference, it is transformed regularly
		else {
			edge.transform(edge_Guard, guard, edge.owner)
		}
	}
	
	/**
	 * This rule is responsible for transforming the updates.
	 * It depends on sameRegionTransitionsRule, exitAssignmentActionsOfStatesRule, exitEventRaisingActionsOfStatesRule and ExpressionTransformer.
	 */
	val assignmentActionsRule = createRule(UpdatesOfTransitions.instance).action [
		// No update on ToHigher transitions, it is done in ToHigherTransitionRule
		for (edge : it.transition.allValuesOfTo.filter(Edge)) {
			for (assignmentStatement : transition.effects.filter(AssignmentStatement)) {
				edge.transformAssignmentAction(edge_Update, assignmentStatement, edge.owner)
			}		
		}
		// The trace is created by the ExpressionTransformer
	].build
	
	/**
	 * This rule is responsible for transforming the entry event updates of states.
	 * It depends on sameRegionTransitionsRule, ExpressionTransformer and all the rules that create nodes.
	 */
	val entryAssignmentActionsOfStatesRule = createRule(EntryAssignmentsOfStates.instance).action [
		for (edge : it.state.allValuesOfTo.filter(Edge)) {
			for (assignmentStatement : state.entryActions.filter(AssignmentStatement)) {
				edge.transformAssignmentAction(edge_Update, assignmentStatement, edge.owner)
			}
			// The trace is created by the ExpressionTransformer
		}
	].build
	
	/**
	 * This rule is responsible for transforming the entry event timeout actions of states. 
	 * (Initializing the timer to 0 on entering a state.)
	 * It depends on sameRegionTransitionsRule, ExpressionTransformer and all the rules that create nodes.
	 */
	val entryTimeoutActionsOfStatesRule = createRule(EntryTimeoutActionsOfStates.instance).action [
		for (edge : it.state.allValuesOfTo.filter(Edge)) {
			edge.transformTimeoutAction(edge_Update, it.setTimeoutAction, edge.owner)
			// The trace is created by the ExpressionTransformer
		}
	].build
	
	/**
	 * This rule is responsible for transforming the exit event updates of states.
	 * It depends on sameRegionTransitionsRule, ExpressionTransformer and all the rules that create nodes.
	 */
	val exitAssignmentActionsOfStatesRule = createRule(ExitAssignmentsOfStatesWithTransitions.instance).action [
		for (edge : it.outgoingTransition.allValuesOfTo.filter(Edge)) {
			for (assignmentStatement : it.state.exitActions.filter(AssignmentStatement)) {
				edge.transformAssignmentAction(edge_Update, assignmentStatement, edge.owner)
			}
		}
		// The trace is created by the ExpressionTransformer
		// The loop synchronization edges already have the exit actions
	].build
	
	/**
	 * This rule is responsible for transforming the raise event actions (raising events) of transitions. (No system out-events.)
	 * It depends on sameRegionTransitionsRule and eventsRule.
	 */
	val eventRaisingActionsRule = createRule(RaisingActionsOfTransitions.instance).action [
		// No event raising on ToHigher transitions, it is done in ToHigherTransitionRule
		for (edge : it.transition.allValuesOfTo.filter(Edge)) {
			val owner = edge.owner  as SynchronousComponentInstance
			for (match : RaiseInstanceEventOfTransitions.Matcher.on(engine).getAllMatches(transition, raiseEventAction, owner, raiseEventAction.port, null, null, null)) {
				edge.createEventRaising(match.inPort, match.raisedEvent, match.inInstance, it.raiseEventAction)
			}
		}
	].build
	
	/**
	 * This rule is responsible for transforming the event actions of transitions that raise signals led out to the system interface.
	 * It depends on sameRegionTransitionsRule, toLowerRegionTransitionsRule, toHigherRegionTransitionsRule and systemOutputSignalsRule.
	 */
	val syncSystemEventRaisingActionsRule = createRule(RaiseTopSystemEventOfTransitions.instance).action [
		// Only if the out event is led out to the main composite system
		val owner = it.instance
		for (edge : it.transition.allValuesOfTo.filter(Edge).filter[it.owner == owner]) {
			edge.createEventRaising(it.outPort, it.raisedEvent, it.instance, it.eventRaiseAction)
		}
	].build
	
	/**
	 * This rule is responsible for transforming the raising event actions (raising events) as entry events. (No out-events.)
	 * It depends on sameRegionTransitionsRule, ExpressionTransformer and all the rules that create nodes.
	 */
	val entryEventRaisingActionsRule = createRule(EntryRaisingActionsOfStates.instance).action [
		for (edge : it.state.allValuesOfTo.filter(Edge)) {
			val owner = edge.owner as SynchronousComponentInstance
			for (match : RaiseInstanceEventStateEntryActions.Matcher.on(engine).getAllMatches(it.state, it.raiseEventAction, owner, it.raiseEventAction.port, it.raiseEventAction.event, null, null)) {
				edge.createEventRaising(match.inPort, match.raisedEvent, match.inInstance, it.raiseEventAction)
			}
		}
	].build
	
	/**
	 * This rule is responsible for transforming the out-event actions (raising event) as entry events.
	 * It depends on sameRegionTransitionsRule, ExpressionTransformer and all the rules that create nodes.
	 */
	val syncSystemEventRaisingOfEntryActionsRule = createRule(RaiseTopSystemEventStateEntryActions.instance).action [
		// Only if the out event is led out to the main composite system
		val owner = it.instance as SynchronousComponentInstance
		for (edge : it.state.allValuesOfTo.filter(Edge).filter[it.owner == owner]) {
			edge.createEventRaising(it.outPort, it.raisedEvent, it.instance, it.entryAction)
		}
	].build
	
	/**
	 * This rule is responsible for transforming the exit event event raisings of states. (No out-events.)
	 * It depends on sameRegionTransitionsRule, ExpressionTransformer and all the rules that create nodes.
	 */
	val exitEventRaisingActionsOfStatesRule = createRule(ExitRaisingActionsOfStatesWithTransitions.instance).action [
		for (edge : it.outgoingTransition.allValuesOfTo.filter(Edge)) {
			val owner = edge.owner as SynchronousComponentInstance
			for (match : RaiseInstanceEventStateExitActions.Matcher.on(engine).getAllMatches(it.state,
					it.raiseEventAction, owner, it.raiseEventAction.port, it.raiseEventAction.event, null, null)) {
				edge.createEventRaising(match.inPort, match.raisedEvent, match.inInstance, it.raiseEventAction)
			}	
		}		
	].build
	
	/**
	 * This rule is responsible for transforming the out-event actions (raising event) as exit events.
	 * It depends on sameRegionTransitionsRule, ExpressionTransformer and all the rules that create nodes.
	 */
	val exitSystemEventRaisingActionsOfStatesRule = createRule(ExitRaisingActionsOfStatesWithTransitions.instance).action [
		for (edge : it.outgoingTransition.allValuesOfTo.filter(Edge)) {
			val owner = edge.owner  as SynchronousComponentInstance
			for (match : RaiseTopSystemEventStateExitActions.Matcher.on(engine).getAllMatches(null, it.state,
					owner, it.raiseEventAction.port, it.raiseEventAction.event, it.raiseEventAction)) {
				edge.createEventRaising(match.outPort, match.raisedEvent, match.instance, match.exitAction)				
			}	
		}		
	].build
	
	/**
	 * Places an event raising equivalent update on the given edge.
	 */
	private def createEventRaising(Edge edge, Port port, Event toRaiseEvent, ComponentInstance inInstance, RaiseEventAction eventAction) {
		val toRaiseVar = toRaiseEvent.getToRaiseVariable(port, inInstance)
		edge.createAssignmentExpression(edge_Update, toRaiseVar, true)
		val exps = eventAction.arguments
		if (!exps.empty) {
			for (expression : exps) {
				val assignment = edge.createAssignmentExpression(edge_Update, toRaiseEvent.getValueOfVariable(port, inInstance), expression, inInstance)
				addToTrace(eventAction, #{assignment}, expressionTrace)
			}			
		}
	}
	
	/**
	 * Places isActive guards on each transition equivalent edge indicating that a transition can only fire when its template is activated.
	 * It depends on sameRegionTransitionRule, toLowerTransitionTule, toHigherTransitionRule.
	 */
	val isActiveRule = createRule(Transitions.instance).action [
		for (edge : it.transition.allValuesOfTo.filter(Edge)) {
			if (it.region.subregion) {
				edge.createIsActiveGuard
			}
		}
	].build
	
	/**
	 * Places guards on edges that specify the priority of transitions of a particular state.
	 * It depends on all rules that place semantical guards on edges.
	 */
	val transitionPriorityRule = createRule(Transitions.instance).action [
		// Note that the order in which the transitions are returned matters, as the guards of
		// already handled edges can be cloned - ugly (same negated expressions might appear),
		// but not a problem in reality
		val containingStatechart = it.transition.containingStatechart
		if (containingStatechart.transitionPriority != TransitionPriority.OFF) {
			val prioritizedTransitions = it.transition.prioritizedTransitions
			for (edge : it.transition.allValuesOfTo.filter(Edge)) {
				val owner = edge.owner
				for (higherPriorityTransition : prioritizedTransitions) {
					val higherPriorityEdges = higherPriorityTransition.allValuesOfTo.filter(Edge).filter[it.owner == owner]
					for (higherPriorityGuard : higherPriorityEdges.map[it.guard].filterNull) {
						edge.addGuard(
							createNegationExpression => [
								it.negatedExpression = higherPriorityGuard.clone(true, true)
							],
							LogicalOperator.AND
						)
					}
				}
			}
		}
	].build
	
	val transitionTimedTransitionPriorityRule = createRule(Transitions.instance).action [
		// Priorities regarding time trigger guards have to be handled separately due to 
		// the timing location mapping style
		val containingStatechart = it.transition.containingStatechart
		if (containingStatechart.transitionPriority != TransitionPriority.OFF) {
			val prioritizedTransitions = it.transition.prioritizedTransitions
			for (edge : it.transition.allValuesOfTo.filter(Edge)) {
				for (higherPriorityTransition : prioritizedTransitions) {
					val timeMatches = TimeTriggersOfTransitions.Matcher.on(engine).getAllMatches(null, higherPriorityTransition, null, null, null, null)
					if (!timeMatches.isEmpty) {
						val originalGuard = edge.guard
						for (timeMatch : timeMatches) {
							val clockVar = timeMatch.timeoutDeclaration.allValuesOfTo.filter(ClockVariableDeclaration).head
							val timeValue = timeMatch.time.convertToMs
							if (originalGuard !== null) {
								// The negation of "greater or equals" is "less"
								edge.insertLogicalExpression(edge_Guard, CompareOperator.LESS, clockVar,
									timeValue, originalGuard, timeMatch.timeoutEventReference, LogicalOperator.AND)
							}
							else {
								edge.insertCompareExpression(edge_Guard, CompareOperator.LESS, clockVar,
									timeValue, timeMatch.timeoutEventReference)
							}
						}
					}
				}
			}
		}
	].build
	
	private def getPrioritizedTransitions(Transition gammaTransition) {
		val gammaStatechart = gammaTransition.containingStatechart
		val transitionPriority = gammaStatechart.transitionPriority
		val gammaOutgoingTransitions = gammaTransition.sourceState.outgoingTransitions
		val prioritizedTransitions = newLinkedList
		switch (transitionPriority) {
			case OFF: {
				// No operation
			}
			case ORDER_BASED : {
				for (gammaOutgoingTransition : gammaOutgoingTransitions) {
					if (gammaOutgoingTransitions.indexOf(gammaOutgoingTransition) < 
							gammaOutgoingTransitions.indexOf(gammaTransition)) {
						prioritizedTransitions += gammaOutgoingTransition
					}
				}
			}
			case VALUE_BASED : {
				for (gammaOutgoingTransition : gammaOutgoingTransitions) {
					if (gammaOutgoingTransition.priority > gammaTransition.priority) {
						prioritizedTransitions += gammaOutgoingTransition
					}
				}
			}
			default: {
				throw new IllegalArgumentException("Not known priority enum literal: " + transitionPriority)
			}
		}
		return prioritizedTransitions
	}
	
	/**
	 * Places guards (conjunction of the negated expressions of adjacent edges) for the default edges of choices. 
	 */
	val defultChoiceTransitionsRule = createRule(DefaultTransitionsOfChoices.instance).action [
		for (edge : it.defaultTransition.allValuesOfTo.filter(Edge)) {
			val owner = edge.owner
			val otherEdge = it.otherTransition.allValuesOfTo.filter(Edge).filter[it.owner == owner].head
			if (otherEdge.guard === null) {
				throw new IllegalArgumentException("A choice has two default outgoing transitions: " + edge + "\n" + otherEdge)
			}
			edge.addNegatedExpression(otherEdge.guard)
		}
	].build
	
	/**
	 * Places the negated form of the given expression onto the given edge.
	 */
	private def addNegatedExpression(Edge edge, Expression expression) {
		val negatedExp = createNegationExpression
		negatedExp.copy(negationExpression_NegatedExpression, expression)
		edge.addGuard(negatedExp, LogicalOperator.AND)
	}
	
	private def instantiateTemplates(Collection<Template> templates) {
		val instationList = target.systemDeclarations.system.createChild(system_InstantiationList, instantiationList) as InstantiationList 
		for (template : templates) {
			instationList.template += template
		}
	}
	
	private def instantiateUninstantiatedTemplates() {
		val instantiatedTemplates = target.systemDeclarations.system.instantiationList.map[it.template].flatten.toList
		instantiateTemplates(target.template.filter[!instantiatedTemplates.contains(it)].toList /* Uninstantiated templates */)
	}
	
	/**
	 * Responsible for simplifying the created Uppaal model where it is possible.
	 */
	private def cleanUp() {
		deleteEntryLocations
	}
	
	/**
	 * Deletes entry locations of simple states without entry actions.
	 */
	private def deleteEntryLocations() {
		// Removing the unnecessary committed locations before the simple state locations
		for (simpleState : SimpleStates.Matcher.on(engine).allValuesOfstate) {
			for (entryEdge : simpleState.allValuesOfTo.filter(Edge)) {
				if (entryEdge.plain) {
					val template = entryEdge.parentTemplate
					// Retargeting the incoming edges to the target location
					for (edge : template.edge.filter[it.target == entryEdge.source]) {
						edge.target = entryEdge.target
					}
					template.location.remove(entryEdge.source)
					// Removing them from the trace
					entryEdge.source.removeTrace
					entryEdge.delete
				}
			}
		}
	}
	
	/**
	 * Creates trace entries posteriorly to make it more complete.
	 */
	private def void extendTrace() {
		clockLocationTraceRule.fireAllCurrent
	}
	
	val clockLocationTraceRule = createRule(EdgesWithClock.instance).action [
		val source = it.edge.source
		val target = it.edge.target
		val state = source.allValuesOfFrom.head
		addToTrace(state, #{target}, trace)
	].build
	
	 /**
	 * Deletes and edge from its template and the trace model.
	 */
	private def delete(Edge edge) {
		val parentTemplate = edge.parentTemplate
		parentTemplate.edge.remove(edge)
		edge.removeTrace 
	}
	
	/**
	 * Returns whether the given edge is plain, i.e. it does not contain any synchronization, guard or update.
	 */
	private def boolean isPlain(Edge edge) {
		return (edge.synchronization === null && edge.guard === null && edge.update.empty)
	}
	
	/**
	 * Responsible for returning a map that contains all templates and their location names in a map.
	 */
	def Map<String, String[]> getTemplateLocationsMap() {
		val templateLocationMap = new HashMap<String, String[]>
		// VIATRA matches cannot be used here, as testedComponentsForStates has different pointers for some reason
		for (instance : testedComponentsForStates) {
			val statechart = instance.type as StatechartDefinition
			val Set<Region> regions = newHashSet
			for (topRegion : statechart.regions) {
				regions += topRegion
				regions += topRegion.subregions
			}
			for (statechartRegion : regions) {
					var array = new ArrayList<String>
					for (state : statechartRegion.stateNodes.filter(State)) {
						array.add(state.locationName)
					}
					templateLocationMap.put(statechartRegion.regionName + "Of" + instance.name, array)
			}
		}
		return templateLocationMap
	}
	
	def getTransitionIdVariableIntervalValue() {
		return new Pair(INITIAL_TRANSITION_ID, transitionId)
	}
	
	/**
	 * Disposes of the transformer.
	 */
	def dispose() {
		if (transformation !== null) {
			transformation.dispose
		}
		transformation = null
		return
	}
	
}
