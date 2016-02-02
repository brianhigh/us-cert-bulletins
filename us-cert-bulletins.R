# -------------------------------------------------------------------------
# Get the most recent US-CERT Vulnerability Summary Bulletins and explore.
#
# Copyright 2015 Brian High (https://github.com/brianhigh)
# License: GNU GPL v3 http://www.gnu.org/licenses/gpl.txt
# -------------------------------------------------------------------------

# Close connections and clear objects.
closeAllConnections()
rm(list=ls())

# -------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------

# Control which kinds of plots to make.
make.googleVis.plots <- FALSE
make.ggplot.plots    <- TRUE
make.vendors.plots   <- TRUE
make.products.plots  <- TRUE
make.tables          <- TRUE
bulletin.num         <- 7    # 7 (most recent) through 16 are valid here.

# Create the images folder if needed.
imagesdir <- "images"
dir.create(file.path(imagesdir), showWarnings = FALSE, recursive = TRUE)

# -------------------------------------------------------------------------
# Functions
# -------------------------------------------------------------------------

plot_top_ten_vendors <- function(bulletin.df, Severity) {
    # ---------------------------
    # Top Ten Vulnerable Vendors
    # ---------------------------
    
    # Split Vendor and Product into their own variables.
    vendor.df <- extract(bulletin.df, VendProd, 
                         c("Vendor", "Product"), "(.+): (.+)")
    
    # Group by Vendor and Severity for plotting with ggplot().
    vendor.df %>% group_by(Vendor, Severity) %>% 
        summarize(Issues = n()) -> vender.grp
    
    # Find max and min publication dates for titles/captions.
    min.pub <- min(as.character(vendor.df$Pub))
    max.pub <- max(as.character(vendor.df$Pub))
    vendor.title <- paste("Top Ten Vulnerable Vendors: ", 
                          min.pub, "through", max.pub, sep=" ")
    
    # Get vulnerability totals per vendor.
    vendor.df %>% group_by(Vendor) %>% summarize(Total_Issues = n()) %>%
        as.data.frame() %>% arrange(desc(Total_Issues)) -> bulletin.vtot
    vender.grp <- merge(vender.grp, bulletin.vtot, by="Vendor")
    names(vender.grp) <- c("Vendor", "Severity", "Issues", "Total_Issues")
    
    # Sort Vendor factor levels by Total number of Issues per Vendor.
    vender.grp$Vendor <- reorder(vender.grp$Vendor, 
                                 vender.grp[,"Total_Issues"])
    
    if(isTRUE(make.tables)) {
        # List the top-10 vendors by vulnerability (Total_Issues) count.
        head(bulletin.vtot, 10) %>% 
            kable(caption = vendor.title, format="markdown") %>% print
    }
    
    # Remove all but the top ten Vendors.
    top.ten <- head(bulletin.vtot$Vendor, 10)
    vender.grp <- vender.grp[vender.grp$Vendor %in% top.ten,]
    
    # Sort Severity levels again, as they appear to have been scrambled.
    vender.grp$Severity <- as.factor(vender.grp$Severity)
    levels(vender.grp$Severity) <- Severity
    
    if (isTRUE(make.ggplot.plots)) {
        # Make a stacked bar plot of vulnerability scores, colored by severity.
        g <- ggplot(data=vender.grp, aes(x=Vendor, y=Issues, fill=Severity)) + 
                geom_bar(stat="identity") + coord_flip() + 
                ggtitle(vendor.title) + 
                scale_fill_manual(values=cbbPalette[c(2,5,4)]) +
                theme(text = element_text(size=18))
        plot(g)
        png(filename=paste(imagesdir, 
                           paste("vendors", min.pub, "png", sep="."), sep="/"), 
            width=1000, height=800)
        print(g)
        dev.off()
    }
    
    if (isTRUE(make.googleVis.plots)) {
        # Split Severity into three columns with counts of Issues per Severity.
        vender.grp %>% spread(Severity, Issues, fill = 0) %>% 
            arrange(desc(Total_Issues)) -> vender.grp.wide
        
        # Make a stacked bar plot of vulnerability scores, colored by severity.
        p <- gvisBarChart(vender.grp.wide, 
                  yvar=c("High", "Med", "Low"), 
                  xvar="Vendor",
                  options=list(isStacked=TRUE,
                       colors="['#E69F00', '#F0E442', '#009E73']", 
                       width=1000, height=800,
                       title=vendor.title,
                       titleTextStyle="{fontSize:36}",
                       vAxes="[{title:'Vendor', textStyle:{fontSize:20}}]",
                       hAxes="[{title:'Issues', textStyle:{fontSize:20}}]",
                       tooltipTextStyle="{color: 'blue', fontSize:20}"))
        plot(p)
    }
    return(TRUE)
}
    
plot_top_ten_products <- function(bulletin.df, Severity) {
    # ---------------------------
    # Top Ten Vulnerable Products
    # ---------------------------
    
    # Make a copy of bulletin.df that renames VendProd with Product.
    bulletin.df %>% select(Product = VendProd, everything()) -> product.df
    
    # Abbreviate the Product variable for plot labels: use first 3 "words".
    product.df %>% 
        mutate(
            Product=gsub("((?:\\w+[:_ -]+){3}).*", "\\1", Product)) -> 
        product.df
    
    # Group by Product and Severity for plotting with ggplot().
    product.df %>% group_by(Product,Severity) %>% 
        summarize(Issues = n()) -> product.grp
    
    # Find max and min publication dates for titles/captions.
    min.pub <- min(as.character(product.df$Pub))
    max.pub <- max(as.character(product.df$Pub))
    product.title <- paste("Top Ten Vulnerable Products: ", 
                           min.pub, "through", max.pub, sep=" ")
    
    # Sort Product factor levels by Total number of Issues per Product.
    product.df %>% group_by(Product) %>% summarize(Total_Issues = n()) %>%
        as.data.frame() %>% arrange(desc(Total_Issues)) -> bulletin.vtot
    
    if(isTRUE(make.tables)) {
        # List the top-10 Products by Total_Issues (vulnerabilities) count.
        head(bulletin.vtot, 10) %>% 
            kable(caption = product.title, format="markdown") %>% print
    
        # Show the vulnerabilities for these products.
        product.df[product.df$Product %in% head(bulletin.vtot$Product, 10),
                   c("Product", "Severity", "Score", "Info")] %>% 
            kable(caption = product.title, format="markdown") %>% print
    }
    
    # Sort Product factor levels by total number of Issues per Product.
    product.grp <- merge(product.grp, bulletin.vtot, by="Product")
    names(product.grp) <- c("Product", "Severity", "Issues", "Total_Issues")
    product.grp$Product <- reorder(product.grp$Product, 
                                   product.grp[,"Total_Issues"])
    
    # Remove all but the top ten Products.
    top.ten <- head(bulletin.vtot$Product, 10)
    product.grp <- product.grp[product.grp$Product %in% top.ten,]
    
    # Sort Severity levels again, as they appear to have been scrambled.
    product.grp$Severity <- as.factor(product.grp$Severity)
    levels(product.grp$Severity) <- Severity
    
    if (isTRUE(make.ggplot.plots)) {
        # Make a stacked bar plot of vulnerability scores, colored by severity.
        g <- ggplot(data=product.grp, aes(x=Product, y=Issues, fill=Severity)) + 
                geom_bar(stat="identity") + coord_flip() + 
                ggtitle(product.title) + 
                scale_fill_manual(values=cbbPalette[c(2,5,4)]) +
                theme(text = element_text(size=18))
        plot(g)
        png(paste(imagesdir, 
                  paste("products", min.pub, "png", sep="."), sep="/"), 
            width=1000, height=800)
        print(g)
        dev.off()
    }
    
    if (isTRUE(make.googleVis.plots)) {
        # Split Severity into three columns with counts of Issues per Severity.
        product.grp %>% spread(Severity, Issues, fill = 0) %>% 
            arrange(desc(Total_Issues)) -> product.grp.wide
        
        # Make a stacked bar plot of vulnerability scores, colored by severity.
        p <- gvisBarChart(product.grp.wide, 
                  yvar=c("High", "Med", "Low"), 
                  xvar="Product",
                  options=list(isStacked=TRUE,
                       colors="['#E69F00', '#F0E442', '#009E73']", 
                       width=1000, height=800,
                       title=product.title,
                       titleTextStyle="{fontSize:32}",
                       vAxes="[{title:'Product', textStyle:{fontSize:20}}]",
                       hAxes="[{title:'Issues', textStyle:{fontSize:20}}]",
                       tooltipTextStyle="{color: 'blue', fontSize:20}"))
        plot(p)
    }
    return(TRUE)
}

process_data <- function(bulletin.html) {
    
    # Parse the HTML table of vulnerability items.
    bulletin <- readHTMLTable(bulletin.html, validate=FALSE)
    
    # Todo: catch errors and skip onto next bulletin if fails.
    
    # Set levels for Severity ranking.
    Severity <- c("High", "Med", "Low")
    
    # Combine the 3 tables ("High", "Med", "Low") into one data.frame.
    bulletin.df <- do.call("rbind", (lapply(1:3, function(x) {
        names(bulletin[[x]])=c("VendProd", "Desc", "Pub", "Score", "Info")
        bulletin[[x]]$Severity <- rep(Severity[x], nrow(bulletin[[x]]))
        bulletin[[x]]})))
    
    # Remove extra charcaters after CVE number.
    bulletin.df$Info <- gsub("(CVE-\\d{4}-\\d+).*", "\\1", bulletin.df$Info)
    
    # Convert Score to numeric for use on x or y axis of plot.
    bulletin.df$Score <- as.numeric(as.character(bulletin.df$Score))
    
    # Sort vulnerabilty levels.
    levels(bulletin.df$Severity) <- Severity
    
    # Clean up the VendProd variable string for use in plot labels.
    bulletin.df %>% 
        mutate(VendProd = gsub(" -- ", ": ", x=VendProd, fixed = TRUE)) %>% 
        mutate(VendProd = gsub("_$", "", VendProd)) %>%
        mutate(VendProd = gsub("(^|[:_ -])([[:alpha:]])", "\\1\\U\\2",VendProd, 
                               perl=TRUE)) %>% 
        mutate(VendProd = gsub("_", " ", VendProd)) -> bulletin.df
    
    # Make the plots and tables.
    if (isTRUE(make.vendors.plots)) {
        ret.val <- plot_top_ten_vendors(bulletin.df, Severity)
    }
    if (isTRUE(make.products.plots)) {
        ret.val <- plot_top_ten_products(bulletin.df, Severity)
    }
    return(TRUE)
}

# -------------------------------------------------------------------------
# Main Routine
# -------------------------------------------------------------------------

# Install packages and load into memory
for (pkg in c("knitr", "XML", "tidyr", "ggplot2", "dplyr", "googleVis")) {
    if(pkg %in% rownames(installed.packages()) == FALSE) {
        install.packages(pkg, quiet = TRUE, 
                         repos="http://cran.fhcrc.org",
                         dependencies=TRUE)
    }
    suppressWarnings(suppressPackageStartupMessages(
        require(pkg, character.only = TRUE, quietly = TRUE)))
}


# Define a color-blind-friendly palette to use for ggplot().
cbbPalette <- c("#000000", "#E69F00", "#56B4E9", "#009E73", "#F0E442", 
                "#0072B2", "#D55E00", "#CC79A7")

# Get XML file from RSS feed link.
cert.url <- 'https://www.us-cert.gov/ncas/bulletins.xml'

# Error: XML content does not seem to be XML [...]
#doc <- xmlTreeParse(cert.url)  # Dang!

# Can't load with xmlTreeParse, so have to do it the "hard way"...
file.name <- 'bulletins.xml'
download.file(url = cert.url, destfile = file.name)

# Read the file and find the beginning and end of the XML document.
lines <- readLines(file.name)
start <- grep('<?xml version="1.0" encoding="utf-8" ?>', lines, fixed=T)
end   <- c(start[-1]-1, length(lines))

# Remove duplicate xmlns:atom definition
lines <- gsub("(xmlns:atom=[^> ]+) xmlns:atom=[^> ]+", "\\1", lines)

# Combine the lines of the XML document and parse.
doc   <- xmlTreeParse(paste(lines[start:end], collapse="\n"), asText = TRUE, 
                      validate = FALSE)

# Parse the XML to get the embedded most recent bulletin's HTML table.
xmltop <- xmlRoot(doc[[1]])
bulletins <- xmlSApply(xmltop, function(x) xmlSApply(x, xmlValue))

# Process each bulletin of interest.
# bulletins[[7]][[1]] through bulletins[[16]][[1]] are the weekly bulletins.
ret.val <- sapply(bulletin.num, function(x) process_data(bulletins[[x]][[1]]))

# Todo: take as a result the df and rbind all into single and make a xy plot.

