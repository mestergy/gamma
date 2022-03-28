package hu.bme.mit.gamma.scxml.transformation.parse;

import hu.bme.mit.gamma.expression.language.parser.antlr.ExpressionLanguageParser;

public class CustomLanguageParser extends ExpressionLanguageParser {
	
	// Set default rule to "Expression" from "ExpressionPackage"
	@Override
	protected String getDefaultRuleName() {
		return "Expression";
	}
	
}
