#! /bin/env ruby
# encoding: utf-8

require "mustache"
require "yaml"
require "fileutils"
require "kramdown"

papers = YAML.load (File.read "papers/list.yml")

now = DateTime.now

baseDir = "out/" # + (now.strftime "%Y-%m-%d-%H-%M-%S") + "/"

def toUrl (title)
  chars = {
    "-" => /[ ':_]/,
    "a" => /[áàâä]/,
    "c" => /[ç]/,
    "e" => /[éèêë]/,
    "i" => /[iï]/,
    "o" => /[ô]/,
    "u" => /[ùûü]/
  }
  title = title.downcase
  chars.each { |char, pattern|
    title.gsub! pattern, char
  }
  title
end

paperList = []

FileUtils.rm_r (Dir.glob "out/*")

papers.each { |paper, chapters|
  # def period: the first and last years of the chapters
  # def status: done unless a chapter is not done; else current or waiting if
  # period does not end at the current year
  range = { "start" => Date.today, "end" => Date.new }
  done = true
  chapterList = {}
  # iterate over chapters to retrieve info (where is fold when we need it?)
  chapters.each { |chapter, infos|
    if infos["date"] < range["start"]
      then range["start"] = infos["date"]
    end
    if infos["date"] > range["end"]
      then range["end"] = infos["date"]
    end
    if not infos["done"]
      then done = false
    end
    chapterList[chapter] = {
      "url" => "/#{ toUrl paper }/#{ toUrl chapter }",
      "active" => false,
      "chapter" => chapter
    }
  }
  # build rendering params
  if range["start"].year == range["end"].year
    then period = range["start"].strftime "%Y"
    else period = (range["start"].strftime "%Y") + "-" + (range["end"].strftime "%Y")
  end
  if done
    then status = "terminé"
    elsif now.year == range["end"].year
      then status = "en cours"
      else status = "en pause"
  end
  # render and write
  chapList = []
  chapters.each { |chapter, infos|
    chapList = []
    chapterList.dup.each { |k, value|
      if value["chapter"] == chapter
        then value["active"] = true
        else value["active"] = false
      end
      chapList << value
    }
    text = File.read "papers/#{ paper }/#{ chapter }.markdown"
    text += "\n<p class=\"continue\">(à compléter)</p>" unless infos["done"]
    comment = if File.exists? "papers/#{ paper }/#{ chapter }-comment.markdown"
      then Kramdown::Document.new(File.read "papers/#{ paper }/#{ chapter }-comment.markdown").to_html
      else ""
    end
    puts "papers/#{ paper }/#{ chapter }"
    renderVars = {
      "chapter" => chapter,
      "paper" => paper,
      "period" => period,
      "status" => status,
      "chapterList" => chapList,
      "text" => Kramdown::Document.new(text).to_html,
      "comment" => comment,
      "date" => (infos["date"].strftime "%d/%m/%Y")
    }
    dirs = "#{ baseDir + (toUrl paper) }/#{ toUrl chapter }"
    FileUtils.mkdir_p dirs
    File.write(
      dirs + "/index.html",
      Mustache.render(File.read("tpl/chapter.mustache"), renderVars)
    )
  }
  # add paper to paperList
  paperList << {
    "url" => chapList[0]["url"],
    "paper" => paper,
    "period" => period,
    "status" => status
  }
}
# css
FileUtils.mkdir(baseDir + "css")
FileUtils.cp("media/css/chapter.css", (baseDir + "css/chapter.css"))
# render and write homepage
FileUtils.cp "tpl/hello.mustache", (baseDir + "index.html")
# render and write paper list
FileUtils.mkdir (baseDir + "liste")
File.write(
  baseDir + "liste/index.html",
  Mustache.render(File.read("tpl/list.mustache"), "paperList" => paperList)
)
