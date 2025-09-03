module dragon.templates;

import std.stdio;
import std.string;
import std.array;
import std.conv;
import std.algorithm;
import std.range;
import std.regex;

abstract class TemplateValue
{
	abstract bool isTruthy() const;
	abstract bool isArray() const;
	abstract bool isObject() const;

	TemplateArray asArray()
	{
		return cast(TemplateArray) this;
	}

	TemplateObject asObject()
	{
		return cast(TemplateObject) this;
	}
}

class TemplateString : TemplateValue
{
	string value;

	this(string value)
	{
		this.value = value;
	}

	override string toString() const
	{
		return value;
	}

	override bool isTruthy() const
	{
		return value.length > 0;
	}

	override bool isArray() const
	{
		return false;
	}

	override bool isObject() const
	{
		return false;
	}
}

class TemplateNumber : TemplateValue
{
	double value;

	this(double value)
	{
		this.value = value;
	}

	this(long value)
	{
		this.value = cast(double) value;
	}

	override string toString() const
	{
		if (value == cast(long) value)
		{
			return to!string(cast(long) value);
		}
		return to!string(value);
	}

	override bool isTruthy() const
	{
		return value != 0.0;
	}

	override bool isArray() const
	{
		return false;
	}

	override bool isObject() const
	{
		return false;
	}
}

class TemplateBool : TemplateValue
{
	bool value;

	this(bool value)
	{
		this.value = value;
	}

	override string toString() const
	{
		return value ? "true" : "false";
	}

	override bool isTruthy() const
	{
		return value;
	}

	override bool isArray() const
	{
		return false;
	}

	override bool isObject() const
	{
		return false;
	}
}

class TemplateNull : TemplateValue
{
	override string toString() const
	{
		return "";
	}

	override bool isTruthy() const
	{
		return false;
	}

	override bool isArray() const
	{
		return false;
	}

	override bool isObject() const
	{
		return false;
	}
}

class TemplateObject : TemplateValue
{
	TemplateValue[string] data;

	this(TemplateValue[string] data = null)
	{
		this.data = data ? data : (TemplateValue[string]).init;
	}

	bool hasKey(string key)
	{
		return (key in data) !is null;
	}

	TemplateValue getValue(string key)
	{
		if (key in data)
		{
			return data[key];
		}
		return new TemplateNull();
	}

	override string toString() const
	{
		return "[Object]";
	}

	override bool isTruthy() const
	{
		return data.length > 0;
	}

	override bool isArray() const
	{
		return false;
	}

	override bool isObject() const
	{
		return true;
	}
}

class TemplateArray : TemplateValue
{
	TemplateValue[] items;

	this(TemplateValue[] items = null)
	{
		this.items = items ? items : [];
	}

	override string toString() const
	{
		return "[Array]";
	}

	override bool isTruthy() const
	{
		return items.length > 0;
	}

	override bool isArray() const
	{
		return true;
	}

	override bool isObject() const
	{
		return false;
	}
}

enum TokenType
{
	Text,
	Variable,
	UnescapedVariable,
	Section,
	InvertedSection,
	EndSection,
	Comment,
	Partial
}

struct Token
{
	TokenType type;
	string content;
	string key;
	size_t position;
}

class TemplateContext
{
	TemplateValue[string] data;
	TemplateContext parent;

	this(TemplateValue[string] data, TemplateContext parent = null)
	{
		this.data = data;
		this.parent = parent;
	}

	TemplateValue getValue(string key)
	{
		auto parts = split(key, ".");
		TemplateValue current;

		if (parts[0] in data)
		{
			current = data[parts[0]];
		}
		else if (parent !is null)
		{
			return parent.getValue(key);
		}
		else
		{
			return new TemplateNull();
		}

		for (size_t i = 1; i < parts.length; i++)
		{
			if (current.isObject())
			{
				auto obj = current.asObject();
				if (obj.hasKey(parts[i]))
				{
					current = obj.getValue(parts[i]);
				}
				else
				{
					return new TemplateNull();
				}
			}
			else
			{
				return new TemplateNull();
			}
		}

		return current;
	}

	bool hasKey(string key)
	{
		auto parts = split(key, ".");
		TemplateValue current;

		if (parts[0] in data)
		{
			current = data[parts[0]];
		}
		else if (parent !is null)
		{
			return parent.hasKey(key);
		}
		else
		{
			return false;
		}

		for (size_t i = 1; i < parts.length; i++)
		{
			if (current.isObject())
			{
				auto obj = current.asObject();
				if (obj.hasKey(parts[i]))
				{
					current = obj.getValue(parts[i]);
				}
				else
				{
					return false;
				}
			}
			else
			{
				return false;
			}
		}

		return true;
	}
}

class DragonTemplate
{
	private Token[] tokens;
	private string templateText;

	this(string template_)
	{
		this.templateText = template_;
		this.tokens = parse(template_);
	}

	private Token[] parse(string template_)
	{
		Token[] result;
		Regex!char tripleRe = regex(r"\{\{\{([^}]*)\}\}\}", "g");
		Regex!char doubleRe = regex(r"\{\{([#^/!&>]?)([^}]*)\}\}", "g");

		size_t lastEnd = 0;

		auto tripleMatches = matchAll(template_, tripleRe);
		foreach (match; tripleMatches)
		{
			size_t pos = match.hit.ptr - template_.ptr;

			if (pos > lastEnd)
			{
				string textContent = template_[lastEnd .. pos];
				if (textContent.length > 0)
					result ~= Token(TokenType.Text, textContent, "", lastEnd);
			}

			string content = match.captures[1].strip();
			result ~= Token(TokenType.UnescapedVariable, match.hit, content, pos);
			lastEnd = pos + match.hit.length;
		}

		auto doubleMatches = matchAll(template_, doubleRe);
		foreach (match; doubleMatches)
		{
			size_t pos = match.hit.ptr - template_.ptr;

			if (pos < lastEnd)
				continue;

			if (pos > lastEnd)
			{
				string textContent = template_[lastEnd .. pos];
				if (textContent.length > 0)
					result ~= Token(TokenType.Text, textContent, "", lastEnd);
			}

			string modifier = match.captures[1];
			string content = match.captures[2].strip();

			switch (modifier)
			{
			case "#":
				result ~= Token(TokenType.Section, match.hit, content, pos);
				break;
			case "^":
				result ~= Token(TokenType.InvertedSection, match.hit, content, pos);
				break;
			case "/":
				result ~= Token(TokenType.EndSection, match.hit, content, pos);
				break;
			case "!":
				result ~= Token(TokenType.Comment, match.hit, content, pos);
				break;
			case "&":
				result ~= Token(TokenType.UnescapedVariable, match.hit, content, pos);
				break;
			case ">":
				result ~= Token(TokenType.Partial, match.hit, content, pos);
				break;
			default:
				result ~= Token(TokenType.Variable, match.hit, content, pos);
				break;
			}

			lastEnd = pos + match.hit.length;
		}

		if (lastEnd < template_.length)
		{
			result ~= Token(TokenType.Text, template_[lastEnd .. $], "", lastEnd);
		}

		return result;
	}

	string render(TemplateValue[string] context)
	{
		auto ctx = new TemplateContext(context);
		return renderTokens(tokens, ctx).strip();
	}

	private string renderTokens(Token[] tokens, TemplateContext context)
	{
		string result;
		size_t i = 0;

		while (i < tokens.length)
		{
			auto token = tokens[i];

			switch (token.type)
			{
			case TokenType.Text:
				result ~= token.content;
				break;

			case TokenType.Variable:
				result ~= escapeHtml(getValue(token.key, context));
				break;

			case TokenType.UnescapedVariable:
				result ~= getValue(token.key, context);
				break;

			case TokenType.Comment:
				break;

			case TokenType.Section:
				auto sectionResult = renderSection(tokens, i, context, false);
				result ~= sectionResult.output;
				i = sectionResult.nextIndex - 1;
				break;

			case TokenType.InvertedSection:
				auto invertedResult = renderSection(tokens, i, context, true);
				result ~= invertedResult.output;
				i = invertedResult.nextIndex - 1;
				break;

			case TokenType.EndSection:
				break;

			case TokenType.Partial:
				result ~= "<!-- Partial: " ~ token.key ~ " -->";
				break;

			default:
				break;
			}

			i++;
		}

		return result;
	}

	private struct SectionResult
	{
		string output;
		size_t nextIndex;
	}

	private SectionResult renderSection(Token[] tokens, size_t startIndex,
		TemplateContext context, bool inverted)
	{
		auto startToken = tokens[startIndex];
		string sectionKey = startToken.key;

		size_t endIndex = findEndSection(tokens, startIndex, sectionKey);
		if (endIndex == size_t.max)
		{
			throw new Exception("Unclosed section: " ~ sectionKey);
		}

		Token[] sectionTokens = tokens[startIndex + 1 .. endIndex];

		TemplateValue value = context.getValue(sectionKey);

		string result;

		if (inverted)
		{
			if (!value.isTruthy())
			{
				result = renderTokens(sectionTokens, context);
			}
		}
		else
		{
			if (value.isTruthy())
			{
				if (value.isArray())
				{
					auto arr = value.asArray();
					foreach (i, item; arr.items)
					{
						TemplateValue[string] itemContext = createItemContext(item, i);
						auto childContext = new TemplateContext(itemContext, context);
						result ~= renderTokens(sectionTokens, childContext);
					}
				}
				else if (value.isObject())
				{
					auto obj = value.asObject();
					auto objContext = new TemplateContext(obj.data, context);
					result = renderTokens(sectionTokens, objContext);
				}
				else
				{
					result = renderTokens(sectionTokens, context);
				}
			}
		}

		return SectionResult(result, endIndex + 1);
	}

	private TemplateValue[string] createItemContext(TemplateValue item, size_t index = size_t.max)
	{
		TemplateValue[string] itemContext;

		if (item.isObject())
			itemContext = item.asObject().data;
		else
			itemContext["."] = item;
		if (index != size_t.max)
			itemContext["@index"] = new TemplateNumber(cast(long) index);

		return itemContext;
	}

	private size_t findEndSection(Token[] tokens, size_t startIndex, string sectionKey)
	{
		int depth = 0;

		for (size_t i = startIndex; i < tokens.length; i++)
		{
			auto token = tokens[i];

			if ((token.type == TokenType.Section || token.type == TokenType.InvertedSection)
				&& token.key == sectionKey)
			{
				depth++;
			}
			else if (token.type == TokenType.EndSection && token.key == sectionKey)
			{
				depth--;
				if (depth == 0)
				{
					return i;
				}
			}
		}

		return size_t.max;
	}

	private string getValue(string key, TemplateContext context)
	{
		if (key == ".")
		{
			if ("." in context.data)
			{
				return context.data["."].toString();
			}
		}

		auto value = context.getValue(key);
		return value.toString();
	}

	private string escapeHtml(string text)
	{
		return text
			.replace("&", "&amp;")
			.replace("<", "&lt;")
			.replace(">", "&gt;")
			.replace("\"", "&quot;")
			.replace("'", "&#x27;");
	}
}

string renderTemplate(string template_, TemplateValue[string] context)
{
	return new DragonTemplate(template_).render(context);
}

TemplateValue templateValue(string value)
{
	return new TemplateString(value);
}

TemplateValue templateValue(long value)
{
	return new TemplateNumber(value);
}

TemplateValue templateValue(int value)
{
	return new TemplateNumber(cast(long) value);
}

TemplateValue templateValue(uint value)
{
	return new TemplateNumber(cast(long) value);
}

TemplateValue templateValue(short value)
{
	return new TemplateNumber(cast(long) value);
}

TemplateValue templateValue(ushort value)
{
	return new TemplateNumber(cast(long) value);
}

TemplateValue templateValue(byte value)
{
	return new TemplateNumber(cast(long) value);
}

TemplateValue templateValue(ubyte value)
{
	return new TemplateNumber(cast(long) value);
}

TemplateValue templateValue(double value)
{
	return new TemplateNumber(value);
}

TemplateValue templateValue(float value)
{
	return new TemplateNumber(cast(double) value);
}

TemplateValue templateValue(real value)
{
	return new TemplateNumber(cast(double) value);
}

TemplateValue templateValue(bool value)
{
	return new TemplateBool(value);
}

TemplateValue templateValue(TemplateValue[string] obj)
{
	return new TemplateObject(obj);
}

TemplateValue templateValue(TemplateValue[] arr)
{
	return new TemplateArray(arr);
}

TemplateValue templateValue(typeof(null) value)
{
	return new TemplateNull();
}
