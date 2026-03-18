x <- readLines("Dataout/docx_new/word/comments.xml", warn = FALSE)
x <- paste(x, collapse = " ")
authors <- regmatches(x, gregexpr("w:author=\"[^\"]+\"", x))[[1]]
authors <- gsub("w:author=\"|\"", "", authors)
texts <- regmatches(x, gregexpr("<w:t>([^<]*)</w:t>", x))[[1]]
texts <- gsub("<w:t>|</w:t>", "", texts)
texts <- texts[nchar(texts) > 0]
n <- min(length(authors), length(texts))
out <- data.frame(author = authors[seq_len(n)], text = texts[seq_len(n)])
write.csv(out, "Dataout/new_doc_comments.csv", row.names = FALSE)
cat("Comments:", n, "\n")
print(out)
