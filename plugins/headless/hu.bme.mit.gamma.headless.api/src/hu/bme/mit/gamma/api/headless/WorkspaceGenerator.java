package hu.bme.mit.gamma.api.headless;

import java.util.logging.Level;

import org.eclipse.core.resources.IWorkspace;
import org.eclipse.core.resources.ResourcesPlugin;
import org.eclipse.equinox.app.IApplicationContext;

public class WorkspaceGenerator extends HeadlessApplicationCommandHandler {

	public WorkspaceGenerator(IApplicationContext context, String[] appArgs) {
		super(context, appArgs);
	}

	public void execute() throws Exception {
		// The workspace will be generated at the destination specified after the -data
		// argument.

		IWorkspace workspace = ResourcesPlugin.getWorkspace();

		logger.log(Level.INFO, "Workspace generated successfully!");
	}
}
