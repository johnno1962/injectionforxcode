/*
 *  objxml.h - OODictionary representation of XML
 *  ========
 *
 *  Created by John Holdsworth on 01/04/2009.
 *  Copyright 2009 © John Holdsworth. All Rights Reserved.
 *
 *  $Id: //depot/ObjCpp/objxml.h#30 $
 *  $DateTime: 2012/11/18 19:11:51 $
 *
 *  C++ classes to wrap up XCode classes for operator overload of
 *  useful operations such as access to NSArrays and NSDictionary
 *  by subscript or NSString operators such as + for concatenation.
 *
 *  This works as the Apple Objective-C compiler supports source
 *  which mixes C++ with objective C. To enable this: for each
 *  source file which will include/import this header file, select
 *  it in Xcode and open it's "Info". To enable mixed compilation,
 *  for the file's "File Type" select: "sourcecode.cpp.objcpp".
 *
 *  For bugs or ommisions please email objcpp@johnholdsworth.com
 *
 *  Home page for updates and docs: http://objcpp.johnholdsworth.com
 *
 *  If you find it useful please send a donation via paypal to account
 *  objcpp@johnholdsworth.com. Thanks.
 *
 *  License
 *  =======
 *
 *  You may make commercial use of this source in applications without
 *  charge but not sell it as source nor can you remove this notice from
 *  this source if you redistribute. You can make any changes you like
 *  to this code before redistribution but you must annotate them below.
 *
 *  For further details http://objcpp.johnholdsworth.com/license.html
 *
 *  THIS CODE IS PROVIDED “AS IS” WITHOUT WARRANTY OF ANY KIND EITHER
 *  EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
 *  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 *
 *  IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
 *  WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MODIFIES AND/OR CONVEYS
 *  THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING
 *  ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT
 *  OF THE USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED
 *  TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED 
 *  BY YOU OR THIRD PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH 
 *  ANY OTHER PROGRAMS), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN
 *  ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
 *
 */

#ifndef _objxml_h_
#define _objxml_h_
#ifdef __cplusplus
#import "objcpp.h"

/*************************************************************************/
/* Add $SDKROOT/usr/include/libxml2 to your project's header search path */
/*************************************************************************/

#import <libxml/tree.h>
#import <libxml/xmlwriter.h>

#define OONodeArray OOArray<OONode>
#define OONodes OONodeArray 

static NSString *kOOChildren = @".children", *kOONodeText = @".nodeText", *kOOTagName = @"@tagName", *kOOTagPrefix = @"@tagPrefix";

/*=================================================================================*/
/*============ Parse NSData XML into OODictionary representation ==================*/

enum OOXMLParserOpts {
	OOXMLDefaultParser = 0x0,
	OOXMLPreserveWhitespace = 0x1,
	OOXMLPreserveCData = 0x2,
	OOXMLStripNamespaces = 0x4,
	OOXMLStripUpperCase = 0x8,

	OOXMLRecursive = 0x10,
	OOXMLRecursiveAtAnyLevel = 0x20,
	// not implemented...
	OOXMLNamespaceSelect = 0x40,
	OOXMLNamespaceSelectAtAnyLevel = 0x80
};

enum OOXMLWriterOpts {
	OOXMLPrettyPrint = 0x1,
	OOXMLDefaultWriter = OOXMLPrettyPrint
};

class OONodeSub;

/**
 Subclass of OODictionary<OOString> to manipulate XML documents. On parsing as XML document
 one OONode is created for each element in the document with the attribute values stored
 as a NSString under a key: "@attributeName". Children of an element, be they pure text
 or sub elements are accumulated in an NSMutableArray under the key @".children" as well
 as in an array with the elements tagName (element name) as the key. This allows simple
 xpath expressions such as document[@"root/child"] to be evaluated by breaking up the
 path into the equivalent of document[@"root"][0][@"child"][0]. To gain efficient
 access to the text inside an element it is also stores under the key @".nodeText"
 in it's parent element.
 */

class OONode : public OODictionary<OOString> {
#ifdef __OBJC_GC__
    NSMutableDictionary *ref2;
protected:
	oo_inline virtual id rawset( NSMutableDictionary *val ) OO_RETURNS {
		return OOReference<NSMutableDictionary *>::rawset( ref2 = val );
	}
#endif
public:
	oo_inline OONode() {
		[alloc() setObject:(id)kCFNull forKey:kOOTagName];
	}
	oo_inline OONode( CFNullRef obj ) {
		set( OO_BRIDGE(id)obj );
	}
	oo_inline OONode( id node ) {
		set( node );
	}
	oo_inline OONode( const OONode &node ) { 
		*this = node;
	}
	oo_inline OONode( NSString *tagName ) {
		[alloc() setObject:tagName forKey:kOOTagName];
	}
	oo_inline OONode( cOOString tagName, cOOString nodeText = nil ) {
		[alloc() setObject:tagName forKey:kOOTagName];
		if ( nodeText ) {
			[get() setObject:nodeText forKey:kOONodeText];
			OODictionary<OOArray<OOString> > node = get();
			NSMutableArray *children = node[kOOChildren].alloc( [NSMutableArray class] );
			[children addObject:nodeText];
		}
	}
	oo_inline OONode( NSData *xml, OOXMLParserOpts flags = OOXMLDefaultParser ) {
		parseXML( xml, flags );
	}
	oo_inline OONode( const OOData &xml, OOXMLParserOpts flags = OOXMLDefaultParser ) {
		parseXML( xml, flags );
	}
	oo_inline OONode( const OONodeArraySub &sub );
	oo_inline OONode( const OONodeSub &sub );

	oo_inline OONode &operator = ( const OONode &node ) { set( node.get() ); return *this; }
	oo_inline OONode &operator = ( NSData *val ) { return parseXML( val ); }
	oo_inline OONode &operator = ( const OONodeArraySub &sub );
	oo_inline OONode &operator = ( const OONodeSub &sub );

	OONode &parseXML( NSData *xml, OOXMLParserOpts flags = OOXMLDefaultParser );
	OOData writeXML( OOXMLWriterOpts flags = OOXMLDefaultWriter ) const;

	oo_inline OOData data() const { return writeXML(); }
	oo_inline operator OOData () const { return data(); }

	oo_inline OOString string() const { return OOString( data() ); }

	oo_inline OONode &operator += ( const OONode &val ) {
		OODictionary<OONodeArray > node = get();
		NSMutableArray *children = node[kOOChildren].alloc( [NSMutableArray class] );
		[children addObject:val.get()];
		NSString *tagName = [val objectForKey:kOOTagName];
		if ( tagName && tagName != (id)kCFNull ) {
			NSMutableArray *siblings = node[tagName].alloc( [NSMutableArray class] );
			[siblings addObject:val.get()];
		}
		return *this;
	}

	oo_inline OONodeSub operator [] ( id sub ) const;
	oo_inline OONodeSub operator [] ( cOOString sub ) const;
	oo_inline OONodeSub operator [] ( const char *sub ) const;
	oo_inline OOArraySub<OONode> operator [] ( int sub ) const;

	oo_inline OONodeArray children() const {
		return [get() objectForKey:kOOChildren];
	}
	oo_inline OONode child( int which = 0 ) const {
		return children()[ which ];
	}
	oo_inline OOString text( int which = 0 ) const {
		return [get() objectForKey:kOONodeText]; // (id)child( which ).get();
	}

	oo_inline operator OOString () const { return text(); } ///
};

/**
 Internal class repesenting selecting of a node from an xpath selection.
 */

class OONodeArraySub : public OOArraySub<OOString> {
	friend class OONodeSub;

	OONodeArraySub( OODictionarySub<NSMutableArray *> *ref, int sub ) : OOArraySub<OOString>( ref,  sub ) { }

	OOArraySub<NSMutableDictionary *> *nodeReference( BOOL refer = YES ) const {
		if ( refer && this->dref->aref->references )
			this->dref->aref->references++;
		return this->dref->aref;
	}

protected:
	oo_inline virtual id set( id val ) const OO_RETURNS {
		OOArraySub<OOString>::set( val );
		if ( ![kOOChildren isEqualToString:dref->key] ) {
			OODictionary<OONodeArray> node = root ?
                (NSMutableDictionary *)root->get() : dref->parent( YES );
            OONodeArray children = node[kOOChildren].alloc( [NSMutableArray class] );
            children += OONode( val );
            if ( ![val objectForKey:kOOTagName] )
                [val setObject:dref->key forKey:kOOTagName];
		}
		return val;
	}

public:
	oo_inline OONode node() const {
		return nodeReference( NO )->get();
	}
	oo_inline operator OONode () const {
		return node();
	}

	oo_inline OOString text() const {
		return node().text();
	}
	oo_inline operator OOString () const {
		return text();
	}

	oo_inline OONodeSub operator [] ( id sub ) const;
	oo_inline OONodeSub operator [] ( cOOString sub ) const;
	oo_inline OONodeSub operator [] ( const char *sub ) const;
};

/**
 Internal class repesenting selection of node from XPath expression. Normally this
 is the OOString value of the first node selected by the xpath expression but can
 be cast to the first node itself or an array of all qualifying nodes.
 */

class OONodeSub : public OODictionarySub<OOString> {
	friend class OONodeArraySub;
	friend class OONode;

	void supportXPath() {
		OOString Key = *key;

		unichar char0 = Key[0];
		if ( char0 != '@' && char0 != '.' ) {
			OOStringArray path = Key / @"/";

			NSInteger pmax = [path count]-1, firstCharOfLast = [*path[-1] length] ? (*path[-1])[0] : 0;

			if ( firstCharOfLast != '@' && firstCharOfLast != '.' ) { //// && firstCharOfLast != '*' ) {
				path += kOONodeText;
				pmax++;
			}

			if ( pmax > 0 ) {
				OODictionarySub<NSMutableArray *> *exp = root ? 
					new OODictionarySub<NSMutableArray *>( root, *path[0] ) :
					new OODictionarySub<NSMutableArray *>( aref, *path[0] );
				exp->references = 1;

				for ( int i=1 ; i<=pmax ; i++ ) {
					OOString p = path[i];
					int idx = 0;
					if ( [p length] && iswdigit( p[0] ) ) {
						idx = [p intValue];
						i++;
					}

					aref = (OOArraySub<NSMutableDictionary *> *)new OONodeArraySub( exp, idx );
					aref->references = 1;
					if ( i == pmax )
						break;

					if ( (p = path[i]) == @"*" )
						p = kOOChildren;
					exp = new OODictionarySub<NSMutableArray *>( aref, p );
					exp->references = 1;
				}

				key = **path[pmax];
				root = NULL;
                dref = NULL;
			}
		}
	}

	oo_inline OONodeSub( const OODictionary<OOString> *ref, id sub ) : OODictionarySub<OOString>( ref, sub ) {
		supportXPath();
	}
	oo_inline OONodeSub( OOArraySub<NSMutableDictionary *> *ref, id sub ) : OODictionarySub<OOString>( ref, sub ) {
		supportXPath();
	}
	oo_inline OONodeSub( OODictionarySub<NSMutableDictionary *> *ref, id sub ) : OODictionarySub<OOString>( ref, sub ) {
		supportXPath();
	}

	oo_inline virtual id set( id val ) const OO_RETURNS {
		OODictionarySub<OOString>::set( val );
		if ( [kOONodeText isEqualToString:this->key] ) {
            OODictionary<OOArray<OOString> > textNode = this->parent( YES );
            NSMutableArray *children = textNode[kOOChildren].alloc( [NSMutableArray class] );
            [children addObject:val];
		}
		return val;
	}

public:
	// assign and assign by mutable copy 
	oo_inline OONodeSub &operator = ( cOOString val ) { set( val ); return *this; }
	oo_inline OONodeSub &operator = ( NSString *val ) { set( val ); return *this; }
	oo_inline OONodeSub &operator = ( NSMutableString *val ) { set( val ); return *this; }
	oo_inline OONodeSub &operator = ( const char *val ) { *this = OOString( val ); return *this; }
	oo_inline OONodeSub &operator = ( const OOArraySub<OOString> &val ) { set( val.get() ); return *this; }
	oo_inline OONodeSub &operator = ( const OODictionarySub<OOString> &val ) { set( val.get() ); return *this; }
	oo_inline OONodeSub &operator = ( double val ) {
		OO_RELEASE( set( [[NSString alloc] initWithFormat:@"%f", val] ) ); 
		return *this;
	}
	oo_inline OONodeSub &operator = ( int val ) {
		OO_RELEASE( set( [[NSString alloc] initWithFormat:@"%d", val] ) ); 
		return *this;
	}
	oo_inline OONodeSub &operator = ( const OONode &val ) {
		this->aref->set( val.get() ); return *this; 
	}
	oo_inline OONodeSub &operator += ( const OONode &val ) {
		OONode( this->parent(YES) ) += val; return *this; 
	}

	oo_inline OONodeSub operator [] ( id sub ) const {
		if ( this->aref->references )
			this->aref->references++;
		return OONodeSub( this->aref, sub );
	}
	oo_inline OONodeSub operator [] ( cOOString sub ) const {
		return (*this)[(id)sub];
	}
	oo_inline OONodeSub operator [] ( const char *sub ) const {
		return (*this)[OOString(sub)];
	}

	oo_inline OONodeArraySub operator [] ( int sub ) const {
		if ( this->aref->dref->references )
			this->aref->dref->references++;
		OONodeArraySub *node = new OONodeArraySub( this->aref->dref, sub );
		node->references = 1;
		OONodeSub *children = new OONodeSub( (OOArraySub<NSMutableDictionary *> *)node, kOOChildren );
		children->references = 1;
		return OONodeArraySub( (OODictionarySub<NSMutableArray*> *)children, 0 );
	}
	oo_inline BOOL operator ! () {
		return count() == 0;
	}

	oo_inline OONodeArray nodes() const {
		return this->aref ? this->aref->parent( NO ) : nil;
	}
	oo_inline operator OONodeArray () const {
		return nodes();
	}

	oo_inline OONode node( NSInteger which = NSNotFound ) const {
		return nodes()[(int)(which == NSNotFound ? aref->idx : which)]; ///
	}
	oo_inline operator OONode () const {
		return node();
	}

	oo_inline OOString text() const {
		return this->get( NO ); //[this->key characterAtIndex:0] == '@' ? OOString( this->get( NO ) ) : node().text();
	}
	oo_inline operator OOString () const {
		return text();
	}

	oo_inline NSInteger count() const {
		return [nodes() count];
	}
	//oo_inline operator int () const {
	//	return count();
	//}
	//oo_inline operator BOOL () {
	//	return count() > 0;
	//}

	oo_inline OONodeArray children() const {
		return [this->parent( NO ) objectForKey:kOOChildren];
	}
	inline OONode child( int which = 0 ) const {
		return children()[which];
	}

	inline OOStringDictionaryArray dictionaries() const {
		OOStringDictionaryArray out;
		OONodeArray in = nodes();
		for ( NSMutableDictionary *n in *in ) {
			OOStringDictionary values;
			OONode node = n;
			for( NSString *key in [*node allKeys] ) {
				unichar c0 = [key characterAtIndex:0];
				if ( c0 == '.' || c0 == '@' )
					continue;
				values[key] = node[key];
			}
			out += values;
		}
		return out;
	}
	oo_inline operator OOStringDictionaryArray () const {
		return dictionaries();
	}
};

inline OOArraySub<OONode> OONode::operator [] ( int sub ) const {
	OODictionarySub<OONode> *step1 = new OODictionarySub<OONode>( (OODictionary<OONode> *)this, kOOChildren );
	step1->references = 1;
	return (*step1)[sub];
}

inline OONodeSub OONode::operator [] ( id sub ) const {
	return OONodeSub( this, sub );
}

inline OONodeSub OONode::operator [] ( cOOString sub ) const {
	return (*this)[(id)sub];
}

inline OONodeSub OONode::operator [] ( const char *sub ) const {
	return (*this)[OOString(sub)];
}

inline OONodeSub OONodeArraySub::operator [] ( id sub ) const {
	return OONodeSub( nodeReference(), sub );
}

inline OONodeSub OONodeArraySub::operator [] ( cOOString sub ) const {
	return (*this)[(id)sub];
}

inline OONodeSub OONodeArraySub::operator [] ( const char *sub ) const {
	return (*this)[OOString(sub)];
}

template <typename ETYPE>
inline OOArray<ETYPE>::OOArray( const OONodeSub &sub ) { *this = sub; }
template <typename ETYPE>
inline OOArray<ETYPE> &OOArray<ETYPE>::operator = ( const OONodeSub &sub ) { return *this = sub.nodes(); }

inline OOString::OOString( const OONode &sub ) { *this = sub.text(); }
inline OOString::OOString( const OONodeSub &sub ) { *this = sub.text(); }
inline OOString::OOString( const OONodeArraySub &sub ) { *this = sub.text(); }

inline OOString &OOString::operator = ( const OONode &sub ) { return *this = sub.text(); }
inline OOString &OOString::operator = ( const OONodeSub &sub ) { return *this = sub.text(); }
inline OOString &OOString::operator = ( const OONodeArraySub &sub ) { return *this = sub.text(); }

inline OONode::OONode( const OONodeSub &sub ) { *this = sub.node(); }
inline OONode::OONode( const OONodeArraySub &sub ) { *this = sub.node(); }

inline OONode &OONode::operator = ( const OONodeSub &sub ) { return *this = sub.node(); }
inline OONode &OONode::operator = ( const OONodeArraySub &sub ) { return *this = sub.node(); }

#if 1
inline BOOL operator == ( const OONodeSub &left, const OONode &val ) { return left.text() == val.text(); }
inline BOOL operator != ( const OONodeSub &left, const OONode &val ) { return !(left == val); }
//inline BOOL operator == ( const OONodeSub &left, cOOStringval ) { return left.text() == val; }
//inline BOOL operator != ( const OONodeSub &left, cOOStringval ) { return !(left == val); }

inline BOOL operator == ( const OONodeArraySub &left, const OONode &val ) { return left.text() == val.text(); }
inline BOOL operator != ( const OONodeArraySub &left, const OONode &val ) { return !(left == val); }
//inline BOOL operator == ( const OONodeArraySub &left, cOOStringval ) { return left.text() == val; }
//inline BOOL operator != ( const OONodeArraySub &left, cOOStringval ) { return !(left == val); }
#endif

/*=================================================================================*/
/*============ Parse XML NSData into OODictionary representation ==================*/

static xmlSAXHandler ooSaxHandlers;

/**
 SAX Parses an XML document into an OODictionary based represntation. See OONode class
 for description of structure generated.
 */

class OOXMLSaxParser {
	OOStringDictionary tagCache;
	xmlParserCtxtPtr context;

public:
	OOXMLParserOpts flags;
	OOArray<id> children;
	OONodeArray stack;
	OONode index;

	OOXMLSaxParser( OOXMLParserOpts flags = OOXMLDefaultParser );

	oo_inline NSMutableString *unique( const char *value ) {
		OOString tagString = value, unique = tagCache[tagString];
		if ( !unique )
			unique = tagCache[tagString] = tagString;
		return unique;
	}

	oo_inline const char *normalize( const char *name, char *buff ) {
		if ( flags & OOXMLStripNamespaces ) {
			const char *colon = strchr( name, ':' );
			if ( colon )
				name = colon+1;
		}
		if ( flags & OOXMLStripUpperCase ) {
			char *out = buff+10, *optr = out;
			while ( *name )
				*optr++ = tolower( *name++ );
			*optr = '\000';
			return out;
		}
		return name;
	}

	oo_inline void addNode( id node, const char *utf8String = NULL, int len = 0 ) {
		OONode parent = stack[-1];
		if ( !children )
			children = parent[kOOChildren].alloc( [NSMutableArray class] );

		if ( utf8String ) {
			static OOPattern nonWhiteSpace( @"\\S" );
			OOArray<OOString> textChildren = children;
			regmatch_t match[] = {{0, len}};
			OOString text = node;

			if ( children>0 && [*children[-1] isKindOfClass:[NSMutableString class]] )
				*textChildren[-1] += node;
			else if ( flags & OOXMLPreserveWhitespace || nonWhiteSpace.exec( utf8String, 0, match, REG_STARTEND ) ) {
				textChildren += text;
				if ( ![*parent objectForKey:kOONodeText] )
					[*parent setObject:node forKey:kOONodeText];
			}
		}
		else
			children += node;
	}

	oo_inline int parse( NSData *chunk ) {
		if ( !context ) {
			OONode root;
			if ( flags & OOXMLRecursive )
				root[@"/"] = index = OONode();
			stack = OONodeArray( root, nil );
			context = xmlCreatePushParserCtxt( &ooSaxHandlers, this, NULL, 0, NULL);
			children = 0;
		}

		const char *bytes = (const char *)[chunk bytes];
		int length = (int)[chunk length];
		while ( length > 0 && bytes[length-1] == '\000' )
			length--;
		return xmlParseChunk(context, bytes, length, 0);
	}

	oo_inline OONode rootNodeForXMLData( NSData *xml = nil ) {
		OOPool pool;
		if ( xml )
			parse( xml );
		xmlParseChunk(context, NULL, 0, 1);
		xmlFreeParserCtxt(context);
		context = NULL;
		return --stack;
	}
};

static void objcppStartElement(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI, 
							   int nb_namespaces, const xmlChar **namespaces, 
							   int nb_attributes, int nb_defaulted, const xmlChar **attributes) {
	char name[10000];
	OOXMLSaxParser &sax = *(OOXMLSaxParser *)ctx;
	OOString tagName = sax.unique( sax.normalize( (const char *)localname, name ) );
	OONode element = OONode( tagName );

	if ( !(sax.flags & OOXMLStripNamespaces) ) {
		if ( prefix )
			[element setObject:sax.unique( (const char *)prefix ) forKey:kOOTagPrefix];

		for ( int ns=0 ; ns < nb_namespaces ; ns++ ) {
			struct _ns { const char *prefix, *nsURI; } *nptr = 
			(struct _ns *)(namespaces + ns*sizeof *nptr/sizeof nptr->prefix);

			snprintf( name, sizeof name-1, nptr->prefix ? "@xmlns:%s" : "@xmlns%.0s", nptr->prefix );
			[element setObject:sax.unique( nptr->nsURI ) forKey:sax.unique( name )];
		}
	}

	for ( int attr_no=0 ; attr_no < nb_attributes ; attr_no++ ) {
		struct _attrs { const char *localName, *prefix, *uri, *value, *end; } *aptr = 
		(struct _attrs *)(attributes + attr_no*sizeof *aptr/sizeof aptr->localName);
		NSInteger vlen = aptr->end-aptr->value;

		OOString value( aptr->value, vlen );
		// attribute value fix required due to libxml2 bug...
		static OOReplace escapeFix = "/&#38;/&/";
		if ( strnstr( aptr->value, "&#38;", vlen ) != NULL )
			value |= escapeFix;

		snprintf( name, sizeof name-1, "@%s", sax.normalize( aptr->localName, name ) );
		[element setObject:sax.unique( value ) forKey:sax.unique( name )];
	}

	sax.stack += element;
	sax.children = 0;
};

static void	objcppEndElement(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI) {
	OOXMLSaxParser &sax = *(OOXMLSaxParser *)ctx;
	OONode element = sax.stack--;
	OONode parent = sax.stack[-1];
	parent += element;
	if ( sax.flags & OOXMLRecursiveAtAnyLevel )
		for ( NSDictionary *n in *sax.stack ) {
			OONode node = n;
			node[@"/"] += element;
		}
	else if ( sax.flags & OOXMLRecursive )
		sax.index += element;
	sax.children = 0;
}

static void	objcppCharacters(void *ctx, const xmlChar *ch, int len) {
	OOXMLSaxParser &sax = *(OOXMLSaxParser *)ctx;
	sax.addNode( OOString( (const char *)ch, len ).get(), (const char *)ch, len );
}

static void objcppCData(void *ctx, const xmlChar *value, int len) {
	OOXMLSaxParser &sax = *(OOXMLSaxParser *)ctx;
	NSData *data = [[NSData alloc] initWithBytes:value length:len];
	sax.addNode( data );
	OO_RELEASE( data );
}

static void objcppSAXError(void *ctx, const char *msg, ...) {
	va_list argp; va_start(argp, msg);
	NSLogv( "OOXMLSaxParser Error - "+OOString( msg ), argp );
	va_end( argp );
}

inline OOXMLSaxParser::OOXMLSaxParser( OOXMLParserOpts flags ) {
	this->flags = flags;

	if ( !ooSaxHandlers.initialized ) {
		ooSaxHandlers.startElementNs = objcppStartElement;
		ooSaxHandlers.endElementNs = objcppEndElement;
		ooSaxHandlers.characters = objcppCharacters;
		ooSaxHandlers.initialized = XML_SAX2_MAGIC;
		ooSaxHandlers.error = objcppSAXError;
	}

	ooSaxHandlers.cdataBlock = this->flags & OOXMLPreserveCData ? objcppCData : NULL;
	context = NULL;
}

inline OONode &OONode::parseXML( NSData *xml, OOXMLParserOpts flags ) {
	return *this = OOXMLSaxParser( flags ).rootNodeForXMLData( xml );
}

/*=================================================================================*/
/*======================== Convert Dictionary back to NSData XML ==================*/

/**
 Class to convert OODictionary representation of XML into an NSData structure to be written to the net.
 */

class OOXMLWriter {
	OOXMLWriterOpts flags;
	int level;

public:
	xmlTextWriterPtr writer;
    char name[1000], value[10000];

	oo_inline void checkrc( const char *what, int rc ) {
		if ( rc < 0 )
			OOWarn( @"Error code returned from %s(): %d", what, rc );
	}

	oo_inline void indent() {
		static char spaces[] = "                                                                ";
		checkrc( "xmlTextWriterWriteFormatString", xmlTextWriterWriteFormatString( writer, "\n%.*s", level*2, spaces ) );
	}

	void traverse( OONode node ) {
		NSString *tagName = [*node objectForKey:kOOTagName];

		if ( tagName && tagName != (id)kCFNull ) {
			if ( flags & OOXMLPrettyPrint && level )
				indent();
			level++;

			NSString *tagPrefix = [*node objectForKey:kOOTagPrefix];
			if ( tagPrefix ) {
				[tagPrefix getCString:name maxLength:sizeof name-1 encoding:NSUTF8StringEncoding];
				strcat( name, ":" );
			}
			else
				name[0] = '\000';

			[tagName getCString:name+strlen(name) maxLength:sizeof name-1-strlen(name) encoding:NSUTF8StringEncoding];
			checkrc( "xmlTextWriterStartElement", xmlTextWriterStartElement( writer, (xmlChar *)name ) );

			for ( NSString *attr in [*node allKeys] ) {
				if ( attr == kOOTagName || attr == kOOTagPrefix || [attr length] == 0 || [attr characterAtIndex:0] != '@' )
					continue;
				[attr getCString:name maxLength:sizeof name-1 encoding:NSUTF8StringEncoding];
				[[*node objectForKey:attr] getCString:value maxLength:sizeof value-1 encoding:NSUTF8StringEncoding];
				checkrc( "xmlTextWriterWriteAttribute", xmlTextWriterWriteAttribute( writer, (xmlChar *)name+1, (xmlChar *)value ) );
			}
		}

		BOOL hadChildElements = NO;
		OONodeArray children = node.children();
		for ( id child in *children )
			if ( [child isKindOfClass:[NSString class]] )
				checkrc( "xmlTextWriterWriteString", xmlTextWriterWriteString( writer, (xmlChar *)[child UTF8String] ) );
			else if ( [child isKindOfClass:[NSData class]] )
				checkrc( "xmlTextWriterWriteFormatCDATA", xmlTextWriterWriteFormatCDATA( writer, "%.*s", (int)[child length], (char *)[child bytes] ) );
			else {
				traverse( child );
				hadChildElements = YES;
			}

		if ( tagName != (id)kCFNull ) {
			level--;
			if ( flags & OOXMLPrettyPrint && hadChildElements )
				indent();
			checkrc( "xmlTextWriterEndElement", xmlTextWriterEndElement( writer ) );
		}
	}

	oo_inline OOXMLWriter( OOXMLWriterOpts flags = OOXMLDefaultWriter ) {
		this->flags = flags;
		level = 0;
	}

	oo_inline OOData dataForNode( const OONode &node ) {
		OOPool pool;
		xmlBufferPtr buf = xmlBufferCreate();
		writer = xmlNewTextWriterMemory(buf, 0);

		NSString *encoding = *node[@"@encoding"];
		checkrc( "xmlTextWriterStartDocument", xmlTextWriterStartDocument(writer, NULL, encoding ? [encoding UTF8String] : "UTF-8", NULL) );

		traverse( node );

		xmlTextWriterEndDocument(writer);
		xmlFreeTextWriter(writer);

		OOData data = [[NSData alloc] initWithBytes:buf->content length:strlen((const char *)buf->content)];
		xmlBufferFree(buf);
		OO_RELEASE( *data );
		return data;
	}
};

inline OOData OONode::writeXML( OOXMLWriterOpts flags ) const {
	return OOXMLWriter( flags ).dataForNode( *this );
}

inline OONode OOURL::xml( int flags ) {
	return OONode( *data(), (OOXMLParserOpts)flags );
}

/**
 Simple SOAP messaging interface.
 */

class OOSoap {
	OOString url, action;
public:
	oo_inline OOSoap( OOString url, OOString action = nil ) {
		this->url = url;
		this->action = action;
	}
	oo_inline OONode send( OONode body, int flags = OOXMLDefaultParser, OOString prefix = @"SOAP-ENV" ) {
		OONode root;
		root[prefix+@":Envelope/@"+prefix+@":encodingStyle"] = @"http://schemas.xmlsoap.org/soap/encoding/";
		root[prefix+@":Envelope/@xmlns:"+prefix] = @"http://schemas.xmlsoap.org/soap/envelope/";
		root[prefix+@":Envelope/@xmlns:SOAP-ENC"] = @"http://schemas.xmlsoap.org/soap/encoding/";
		root[prefix+@":Envelope/@xmlns:xsi"] = @"http://www.w3.org/1999/XMLSchema-instance";
		root[prefix+@":Envelope/@xmlns:xsd"] = @"http://www.w3.org/1999/XMLSchema";

		root[prefix+@":Envelope/"+prefix+@":Body"] += body;

		OORequest req( url );
		[req setHTTPMethod:@"POST"];
		if ( !!action )
			req[@"SOAPAction"] = action;
		req[@"Content-Type"] = @"text/xml";
		[req setHTTPBody:root.data()];
		//NSLog( @"soap: %@ %@ %@", *url, *action, *root.string() );
		return OONode( req.data(), (OOXMLParserOpts)flags );
	}
};

#endif
#endif
