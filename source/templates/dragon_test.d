module templates.dragon_test;

version (unittest)
{
    import dragon.templates;
    import std.stdio;
    import std.string;
    import std.algorithm;
    import std.range;
    import std.regex;

    unittest
    {
        auto template1 = "Hello {{name}}!";
        auto context1 = ["name": templateValue("World")];
        assert(renderTemplate(template1, context1) == "Hello World!");

        auto template2 = "Value: {{value}}";
        auto context2 = [
            "value": templateValue("<script>alert('xss')</script>")
        ];
        assert(renderTemplate(template2, context2) == "Value: &lt;script&gt;alert(&#x27;xss&#x27;)&lt;/script&gt;");

        auto template3 = "Raw: {{{raw}}}";
        auto context3 = ["raw": templateValue("<b>bold</b>")];
        writeln(renderTemplate(template3, context3));
        assert(renderTemplate(template3, context3) == "Raw: <b>bold</b>");

        auto template4 = "{{#items}}<li>{{.}}</li>{{/items}}";
        auto items = [
            templateValue("Apple"), templateValue("Banana"),
            templateValue("Cherry")
        ];
        auto context4 = ["items": templateValue(items)];
        assert(renderTemplate(template4, context4) == "<li>Apple</li><li>Banana</li><li>Cherry</li>");

        auto template5 = "{{^empty}}Not empty{{/empty}}{{#empty}}Empty!{{/empty}}";
        auto context5a = ["empty": templateValue(false)];
        auto context5b = ["empty": templateValue(true)];
        assert(renderTemplate(template5, context5a) == "Not empty");
        assert(renderTemplate(template5, context5b) == "Empty!");

        writeln("All first pass tests passed.");
    }

    unittest
    {
        auto template1 = "Hello {{name}}, you have {{count}} messages!";
        auto context1 = [
            "name": templateValue("Alice"),
            "count": templateValue(5L)
        ];
        assert(renderTemplate(template1, context1) == "Hello Alice, you have 5 messages!");

        writeln("Test 1 passed");
        auto template2 = "User: {{user.name}} ({{user.email}})";
        auto user = [
            "name": templateValue("Bob"),
            "email": templateValue("bob@example.com")
        ];
        auto context2 = ["user": templateValue(user)];
        writeln(renderTemplate(template2, context2));
        assert(renderTemplate(template2, context2) == "User: Bob (bob@example.com)");

        writeln("Test 2 passed");
        auto template3 = `
{{#user}}
Name: {{name}}
{{#address}}
Address: {{street}}, {{city}}
{{/address}}
{{^address}}
No address on file
{{/address}}
{{/user}}`;

        auto userWithAddress = [
            "name": templateValue("Charlie"),
            "address": templateValue([
                "street": templateValue("123 Main St"),
                "city": templateValue("Springfield")
            ])
        ];

        auto userWithoutAddress = [
            "name": templateValue("Dana")
        ];

        auto context3a = ["user": templateValue(userWithAddress)];
        auto expected3a = `Name: Charlie

Address: 123 Main St, Springfield`;
        writeln(renderTemplate(template3.strip(), context3a));

        assert(renderTemplate(template3.strip(), context3a) == expected3a);
        writeln("Test 3a passed");
        auto context3b = ["user": templateValue(userWithoutAddress)];
        auto expected3b = `Name: Dana


No address on file`;
        writeln(renderTemplate(template3.strip(), context3b));
        assert(renderTemplate(template3, context3b) == expected3b);

        writeln("Test 3b passed");
        auto template4 = "Value: {{value}} | Empty: {{empty}} | Null: {{nullValue}}";
        auto context4 = [
            "value": templateValue("test"),
            "empty": templateValue(""),
            "nullValue": templateValue(null)
        ];

        writeln(renderTemplate(template4.strip(), context4));
        assert(renderTemplate(template4, context4) == "Value: test | Empty:  | Null:");
        writeln("Test 4 passed");

        auto template5 = "Escaped: {{html}} | Unescaped: {{{html}}}";
        auto context5 = ["html": templateValue("<div>Test & More</div>")];
        auto expected5 = "Escaped: {{html}} | Unescaped: <div>Test & More</div>";
        writeln(renderTemplate(template5.strip(), context5));
        assert(renderTemplate(template5, context5) == expected5);

        writeln("Test 5 passed");
        auto template6 = "{{#items}}{{@index}}. {{.}} {{/items}}";
        auto items = [
            templateValue("First"),
            templateValue("Second"),
            templateValue("Third")
        ];
        auto context6 = ["items": templateValue(items)];

        writeln(renderTemplate(template6.strip(), context6));
        assert(renderTemplate(template6, context6) == "0. First 1. Second 2. Third");

        writeln("Test 6 passed");
        auto template7 = "{{#outer}}{{#inner}}{{.}} {{/inner}}{{/outer}}";
        auto inner = [
            templateValue("A"),
            templateValue("B")
        ];

        auto outer = ["inner": templateValue(inner)];
        auto context7 = ["outer": templateValue(outer)];
        writeln(renderTemplate(template7.strip(), context7));
        assert(renderTemplate(template7, context7) == "A B");

        writeln("Test 7 passed");
        assert(renderTemplate("", null) == "");
        assert(renderTemplate("Hello World!", null) == "Hello World!");

        writeln("Test 8 passed");
        assert(renderTemplate("{{nonexistent}}", null) == "");
    }

    unittest
    {
        auto htmlTemplate = `
<!DOCTYPE html>
<html>
<head>
    <title>{{title}}</title>
</head>
<body>
    <h1>{{heading}}</h1>
    <ul>
    {{#users}}
        <li>
            <strong>{{name}}</strong> ({{email}})
            {{#isAdmin}}
                <span class="admin-badge">Admin</span>
            {{/isAdmin}}
        </li>
    {{/users}}
    {{^users}}
        <li>No users found</li>
    {{/users}}
    </ul>
</body>
</html>`;

        auto users = [
            templateValue([
                "name": templateValue("John Doe"),
                "email": templateValue("john@example.com"),
                "isAdmin": templateValue(true)
            ]),
            templateValue([
                "name": templateValue("Jane Smith"),
                "email": templateValue("jane@example.com"),
                "isAdmin": templateValue(false)
            ])
        ];

        auto htmlContext = [
            "title": templateValue("User List"),
            "heading": templateValue("Our Users"),
            "users": templateValue(users)
        ];

    }
}
