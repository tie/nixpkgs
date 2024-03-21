import pytest
import typing

from . import flakeuri


@pytest.mark.parametrize("fragment,expect", [
    ("foo", "foo"),
    ("foo@bar", "foo@bar"),
    ("foo bar", "foo bar"),
    ("foo.bar", "foo.bar"),
    ("foo#bar", "foo%23bar"),
    ("\"foo.bar\"", "\"foo.bar\""),
])
def test_quote_url_fragment(
    fragment: str,
    expect: str,
) -> None:
    assert flakeuri.quote_url_fragment(fragment) == expect


@pytest.mark.parametrize("flake_uri,expect", [
    ("", ("", None)),
    ("foo", ("foo", None)),
    ("foo#bar", ("foo", "bar")),
    ("foo#bar#baz", ("foo", "bar#baz")),
    ("foo#bar%23baz", ("foo", "bar#baz")),
    ("foo#bar?baz", ("foo", "bar?baz")),
])
def test_parse_url_fragment(
    flake_uri: str,
    expect: tuple[str, typing.Optional[str]],
) -> None:
    assert flakeuri.parse_url_fragment(flake_uri) == expect


@pytest.mark.parametrize("invalid_attr_name", [
    "\"\"",
    "\"",
])
def test_quote_attr_name_malformed_attribute_name(
    invalid_attr_name: str,
) -> None:
    with pytest.raises(flakeuri.MalformedAttributeName):
        flakeuri.quote_attr_name(invalid_attr_name)


@pytest.mark.parametrize("attr_name,expect", [
    ("foobar", "foobar"),
    ("foo bar", "foo bar"),
    ("foo.bar", "\"foo.bar\""),
    ("", "\"\""),
])
def test_quote_attr_name(
    attr_name: str,
    expect: str,
) -> None:
    assert flakeuri.quote_attr_name(attr_name) == expect


@pytest.mark.parametrize("attr_path,expect", [
    (["foo", "bar"], "foo.bar"),
    (["foo.bar", "baz"], "\"foo.bar\".baz"),
    (["foo#bar"], "foo#bar"),
    (["foo@bar"], "foo@bar"),
    (["foo bar"], "foo bar"),
])
def test_quote_attr_path(
    attr_path: list[str],
    expect: str,
) -> None:
    assert flakeuri.quote_attr_path(attr_path) == expect


@pytest.mark.parametrize("invalid_attr_path", [
    "\"\"\"",
    "\"",
])
def test_parse_attr_path_missing_closing_quote(
    invalid_attr_path: str,
) -> None:
    with pytest.raises(flakeuri.MissingClosingQuote):
        flakeuri.parse_attr_path(invalid_attr_path)


@pytest.mark.parametrize("attr_path,prefix,expect", [
    ("hello.", [], ["hello"]),
    ("\".\"", [], ["."]),
    ("\"foo\" \"bar\"", [], ["foo bar"]),
    (".rootAttr", ["prefix"], ["rootAttr"]),
    ("childAttr", ["prefix"], ["prefix", "childAttr"]),
    ("bar.baz", ["foo"], ["foo", "bar", "baz"]),
    (".", [], []),
    (".", ["prefix"], []),
    ("..", [], [""]),
    ("..", ["prefix"], [""]),
])
def test_parse_attr_path(
    attr_path: str,
    prefix: list[str],
    expect: list[str],
) -> None:
    assert flakeuri.parse_attr_path(attr_path, prefix) == expect
