defmodule Feedme.Parsers.RSS2 do
  import Feedme.Parsers.Helpers

  alias Feedme.XmlNode
  alias Feedme.Feed
  alias Feedme.Entry
  alias Feedme.MetaData
  alias Feedme.Itunes
  alias Feedme.AtomLink
  alias Feedme.Psc
  alias Feedme.Image
  alias Feedme.Enclosure

  def valid?(document) do
    has_version = document
                  |> XmlNode.first("/rss")
                  |> XmlNode.attr("version") == "2.0"

    has_one_channel = document
                      |> XmlNode.first("/rss/channel") != nil

    Enum.all? [ has_version, has_one_channel ]
  end

  def parse(document) do
    %Feed{meta: parse_meta(document), entries: parse_entries(document)}
  end

  def parse_meta(document) do
    channel = XmlNode.first(document, "/rss/channel")

    # image like fields needs special parsing
    ignore_fields = [:image, :skip_hours, :skip_days, :publication_date, :last_build_date, :itunes, :atom_links]
    metadata = parse_into_struct(channel, %MetaData{}, ignore_fields)

    # Parse other fields
    image = XmlNode.first(channel, "image") 
            |> parse_into_struct(%Image{})

    skip_hours = XmlNode.all_try(channel, ["skipHours/hour", "skiphours/hour"])
                 |> Enum.map(&XmlNode.integer/1)

    skip_days = XmlNode.all_try(channel, ["skipDays/day", "skipdays/day"])
                |> Enum.map(&XmlNode.integer/1)

    publication_date = XmlNode.first_try(channel, ["pubDate", "publicationDate"]) 
                       |> parse_datetime

    last_build_date = XmlNode.first_try(channel, ["lastBuildDate", "lastbuildDate"]) 
                      |> parse_datetime

    itunes = parse_into_struct(channel, %Itunes{}, [], "itunes")
    atom_links = XmlNode.children_map(channel, "atom:link", &parse_atom_link_entry/1)

    %{metadata | 
      last_build_date: last_build_date,
      image: image,
      skip_hours: skip_hours,
      skip_days: skip_days,
      publication_date: publication_date,
      last_build_date: last_build_date,
      itunes: itunes,
      atom_links: atom_links
    }
  end

  def parse_entries(document) do
    XmlNode.children_map(document, "/rss/channel/item", &parse_entry/1)
  end

  def parse_entry(node) do
    ignore_fields = [:categories, :enclosure, :publication_date, :itunes, :atom_links]
    entry = parse_into_struct(node, %Entry{}, ignore_fields)

    categories = XmlNode.children_map(node, "category", &XmlNode.text/1)

    enclosure = XmlNode.first(node, "enclosure")
                |> parse_attributes_into_struct(%Enclosure{})

    publication_date = XmlNode.first_try(node, ["pubDate", "publicationDate"])
                       |> parse_datetime

    itunes = parse_into_struct(node, %Itunes{}, [], "itunes")
    psc = parse_psc_entries(node)
    atom_links = XmlNode.children_map(node, "atom:link", &parse_atom_link_entry/1)

    %{entry |
      categories: categories,
      enclosure: enclosure,
      publication_date: publication_date,
      itunes: itunes,
      psc: psc,
      atom_links: atom_links
    }
  end

  def parse_psc_entries(node) do
    XmlNode.children_map(node, "psc:chapters/psc:chapter", &parse_psc_entry/1)
  end

  def parse_psc_entry(node) do
    parse_attributes_into_struct(node, %Psc{})
  end

  def parse_atom_link_entry(node) do
    parse_attributes_into_struct(node, %AtomLink{})
  end

end
