/*
 *  objstr.h - NSString based string class with operators
 *  ========
 *
 *  Created by John Holdsworth on 01/04/2009.
 *  Copyright 2009 © John Holdsworth. All Rights Reserved.
 *
 *  $Id: //depot/ObjCpp/objstr.h#89 $
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

#ifndef _objstr_h_
#define _objstr_h_
#ifdef __cplusplus
#import "objcpp.h"
#import <wctype.h>

// very shortcuts
#define OO (OOString)
#define OOFmt OOFormat

// shortcut equivalent for [NSString stringWithFormat:]
inline NSMutableString *OOFormat( NSString *format, ... ) NS_FORMAT_FUNCTION(1,2) OO_AUTORETURNS;
inline NSMutableString *OOFormat( NSString *format, ... ) {
	va_list argp;
	va_start(argp, format);
	NSMutableString *str = [[NSMutableString alloc] initWithFormat:format arguments:argp];
	va_end( argp );
	return OO_AUTORELEASE( str );
}

/*====================================================================================*/
/*============================= String classes =======================================*/

/**
 Internal class representing a susbscript operation into a string to access or assign
 to individual characters or ranges
 
 Usage:
 <pre>
 OOString str <<= @"JOHN";
 if ( str[1] != 'O' )
 str[1] = 'O';
 </pre>
 */

class OOStringSub {
	friend class OOString;
	OOReference<NSMutableString *> str;
	NSRange idx;

	oo_inline OOStringSub( NSMutableString *ref, int sub ) {
		str = ref;
		idx = NSMakeRange( sub < 0 ? [str length]+sub : sub, 1 );
	}
	oo_inline OOStringSub( NSMutableString *ref, const NSRange &sub ) {
		str = ref;
		idx = sub;
        if ( (NSInteger)idx.length < 0 )
            idx.length = [str length] + idx.length - idx.location;
		else if ( idx.length == NSNotFound )
			idx.length = [str length] - idx.location;
	}
public:
	oo_inline BOOL isupper() { return iswupper( **this ); }
	oo_inline BOOL islower() { return iswlower( **this ); }
    oo_inline unichar operator + () { return towupper( **this ); }
    oo_inline unichar operator - () { return towlower( **this ); }

	oo_inline operator unichar () const {
		return **this;
	}
	oo_inline unichar operator * () const {
		return !!str && idx.location<[str length] ?
            [str characterAtIndex:idx.location] : 0;///
	}
	oo_inline operator NSString * () const OO_AUTORETURNS {
		return [str substringWithRange:idx];
	}

    oo_inline OOStringSub & operator = ( NSString *val ) {
        [str replaceCharactersInRange:idx withString:val];
        return *this;
    }
	oo_inline OOStringSub & operator = ( unichar val ) {
		return *this = [NSString stringWithFormat:@"%c", val];
	}
	oo_inline OOStringSub & operator = ( const char *val ) {
		return *this = [NSString stringWithUTF8String:val];
	}
};

class OOStringSearch;
class OOPattern;

/**
 A string class wrapping around NSString with all the usual operators including subscript.
 OOStringArray is \#defined as OOArray<OOString> and OOStringDict is \#defined as OODictionary<OString>
 for convenience.
 
 Operators:
 <table cellspacing=0><tr><th>operator<th>inplace<th>binary<th>arguments
 <tr><td>assign<td>=<td>&nbsp;<td>String or NSString
 <tr><td>copy<td>&lt;&lt;=<td>&nbsp;<td>String or NSString
 <tr><td>append<td>+=<td>+<td>string or number
 <tr><td>remove<td>-=<td>-<td>string
 <tr><td>repeat<td>*=<td>*<td>count
 <tr><td>split<td>&nbsp;<td>/<td>string
 <tr><td>find<td><td>&amp;<td>pattern
 <tr><td>parse<td><td>^<td>pattern
 <tr><td>replace<td>|=<td>|<td>replace string = "/pat/with/"
 <tr><td>subscript<td>&nbsp;<td>[]<td>character number
 <tr><td>search<td>&nbsp;<td>[]<td>string
 </table>
 
 Usage:
 <pre>
 OOString str <<= @"The time is ";
 NSLog( "%@", *(str+ctime()) );
 </pre>
 */

class OOString : public OOReference<NSMutableString *> {
#ifdef __OBJC_GC__
    NSMutableString *ref2;
	oo_inline virtual id rawset( NSMutableString *val ) OO_RETURNS {
		return OOReference<NSMutableString *>::rawset( ref2 = val );
	}
#endif
public:
	oo_inline OOString() {}
	oo_inline OOString( id val ) { set( val ); }
	oo_inline OOString( cOOString str ) { *this = str; } /// <<= ??
	oo_inline OOString( CFNullRef obj ) { set( OO_BRIDGE(id)obj ); }
	oo_inline OOString( CFStringRef obj ) { set( OO_BRIDGE(id)obj ); }
	oo_inline OOString( const OOStringSub &sub ) { *this = sub; }
	//oo_inline OOString( const OOArraySub<OOString> &sub ) { *this = sub; }
	//oo_inline OOString( const OODictionarySub<OOString> &sub ) { *this = sub; }
	oo_inline OOString( const OONode &sub );
	oo_inline OOString( const OONodeSub &sub );
	oo_inline OOString( const OONodeArraySub &sub );
	oo_inline OOString( int nilOrCapacity ) { *this = nilOrCapacity; }
	oo_inline OOString( long nilOrCapacity ) { *this = nilOrCapacity; }
	oo_inline OOString( OOReference<NSMutableString *> str ) { *this = str; }
	oo_inline OOString( NSMutableString *str ) { *this = str; }
	oo_inline OOString( NSString *str ) { *this = str; }
	oo_inline OOString( double val ) { *this += val; }
	oo_inline OOString( const char *val ) {
		rawset( [[NSMutableString alloc] initWithUTF8String:val] );
	}
	oo_inline OOString( const char *val, NSUInteger len, int encoding = NSUTF8StringEncoding ) {
		rawset( [[NSMutableString alloc] initWithBytes:val length:len encoding:encoding] );
	}
	oo_inline OOString( OOData data, NSStringEncoding encoding = NSUTF8StringEncoding ) {
        rawset( !data ? nil : [[NSMutableString alloc] initWithData:data encoding:encoding] );
	}
	oo_inline OOString( cOOStringArray val ) {
		*this = val.join( @" " );
	}
	oo_inline OOData utf8Data( NSStringEncoding encoding = NSUTF8StringEncoding ) const {
		NSInteger len = [get() lengthOfBytesUsingEncoding:encoding];
		char *bytes = (char *)malloc( len+1 );
		[get() getCString:bytes maxLength:len+1 encoding:encoding];
		OOData out = [[NSData alloc] initWithBytesNoCopy:bytes length:len freeWhenDone:YES];
		OO_RELEASE( *out );
		return out;
	}

	// basic operators
	/// oo_inline NSMutableString *operator & () const { return autoget(); } ////
	oo_inline operator const char * () const {
        if ( get() )
            return [get() UTF8String];
        else
#ifdef DEBUG
            return NULL; // hard crash on nil string during debugging
#else
            return "<nil>"; // be more forgiving on released code
#endif
    }
	oo_inline operator OOData () const { return utf8Data(); }

    // string is "true" if it contains non-numeric or non-zero value
	oo_inline operator double () const { 
		unichar firstChar = (*this)[0];
		return iswdigit( firstChar ) || firstChar == '.' || firstChar == '-' || firstChar == '+' ?
            [get() doubleValue]	: get() ? firstChar : 0;
	}

	oo_inline OOString capitalize() { return [get() capitalizedString]; }
	oo_inline OOString operator + () { return [get() uppercaseString]; }
	oo_inline OOString operator - () { return [get() lowercaseString]; }

	// assignment
	oo_inline OOString &operator = ( NSMutableString *val ) { set( val ); return *this; }
	oo_inline OOString &operator = ( OOReference<NSMutableString *> val ) { set( val ); return *this; }
	oo_inline OOString &operator = ( NSString *val ) {
        OOCopyImmutable( (NSMutableString *)val );
        return *this;
    }
	oo_inline OOString &operator = ( int nilOrCapacity ) { set( nilOrCapacity ); return *this; }
	oo_inline OOString &operator = ( long nilOrCapacity ) { set( nilOrCapacity ); return *this; }
	oo_inline OOString &operator = ( const char *val ) { set( OOString(val).get() ); return *this; }
	oo_inline OOString &operator = ( id val ) { set( val ); return *this; }

	oo_inline OOString &operator = ( cOOString val ) { set( val.get() ); return *this; }
	oo_inline OOString &operator = ( const OOStringSub &val ) { OOCopyImmutable( (NSMutableString *)val ); return *this; }
	oo_inline OOString &operator = ( const OOArraySub<OOString> &val ) { set( val.get() ); return *this; }
	oo_inline OOString &operator = ( const OODictionarySub<OOString> &val ) { set( val.get() ); return *this; }
	oo_inline OOString &operator = ( const OONodeArraySub &sub );
	oo_inline OOString &operator = ( const OONodeSub &sub );
	oo_inline OOString &operator = ( const OONode &sub );

	// inplace operators - append, remove, repeat
	oo_inline OOString &operator += ( id val ) { [alloc() appendString:[val description]]; return *this; }
	oo_inline OOString &operator += ( int val ) { [alloc() appendFormat:@"%d", val]; return *this; }
	oo_inline OOString &operator += ( double val ) { [alloc() appendFormat:@"%f", val]; return *this; }
	oo_inline OOString &operator += ( const char *val ) { [alloc() appendString:OOString( val ).get()]; return *this; }
	oo_inline OOString &operator += ( NSMutableString *str ) { [alloc() appendString:str]; return *this; }
	oo_inline OOString &operator += ( NSString *str ) { [alloc() appendString:str ? str : @"<nil>"]; return *this; }
	oo_inline OOString &operator += ( cOOString str ) { [alloc() appendString:str.get()]; return *this; }
	oo_inline OOString &operator += ( const OOArraySub<OOString> &str ) { [alloc() appendString:str.get()]; return *this; }
	oo_inline OOString &operator += ( const OODictionarySub<OOString> &str ) { [alloc() appendString:str.get()]; return *this; }

	oo_inline OOString &operator -= ( cOOString str );
	oo_inline OOString &operator -= ( NSRange range ) {
        [get() replaceCharactersInRange:range withString:@""];
        return *this;
    }
	oo_inline OOString &operator *= ( NSUInteger count ) {
		NSString *str =[get() copy];
		*this = "";
		for ( int i=0 ; i<count ; i++ )
			*this += str;
        OO_RELEASE( str );
		return *this;
	}
	oo_inline OOString &operator *= ( const OOReference<NSMutableString *> &val ) {
        [alloc() setString:val];
		return *this;
	}

	// string comparison
	oo_inline BOOL operator == ( const char *str ) const { return [get() isEqualToString:OOString(str).get()]; }
	oo_inline BOOL operator != ( const char *str ) const { return !operator == ( str ); }
	oo_inline BOOL operator <  ( const char *str ) const { return [get() caseInsensitiveCompare:OOString(str).get()] == NSOrderedAscending; }
	oo_inline BOOL operator >= ( const char *str ) const { return !operator < ( str ); }
	oo_inline BOOL operator >  ( const char *str ) const { return [get() caseInsensitiveCompare:OOString(str).get()] == NSOrderedDescending; }
	oo_inline BOOL operator <= ( const char *str ) const { return !operator > ( str ); }
	oo_inline BOOL operator == ( NSString *str ) const { return [get() isEqualToString:str]; }
	oo_inline BOOL operator != ( NSString *str ) const { return !operator == ( str ); }
	oo_inline BOOL operator <  ( NSString *str ) const { return [get() caseInsensitiveCompare:str] == NSOrderedAscending; }
	oo_inline BOOL operator >= ( NSString *str ) const { return !operator < ( str ); }
	oo_inline BOOL operator >  ( NSString *str ) const { return [get() caseInsensitiveCompare:str] == NSOrderedDescending; }
	oo_inline BOOL operator <= ( NSString *str ) const { return !operator > ( str ); }
	oo_inline BOOL operator == ( NSMutableString *str ) const { return [get() isEqualToString:str]; }
	oo_inline BOOL operator != ( NSMutableString *str ) const { return !operator == ( str ); }
	oo_inline BOOL operator <  ( NSMutableString *str ) const { return [get() caseInsensitiveCompare:str] == NSOrderedAscending; }
	oo_inline BOOL operator >= ( NSMutableString *str ) const { return !operator < ( str ); }
	oo_inline BOOL operator >  ( NSMutableString *str ) const { return [get() caseInsensitiveCompare:str] == NSOrderedDescending; }
	oo_inline BOOL operator <= ( NSMutableString *str ) const { return !operator > ( str ); }
	oo_inline BOOL operator == ( cOOString str ) const { return [get() isEqualToString:str.get()]; }
	oo_inline BOOL operator != ( cOOString str ) const { return !operator == ( str ); }
	oo_inline BOOL operator <  ( cOOString str ) const { return [get() caseInsensitiveCompare:str.get()] == NSOrderedAscending; }
	oo_inline BOOL operator >= ( cOOString str ) const { return !operator < ( str ); }
	oo_inline BOOL operator >  ( cOOString str ) const { return [get() caseInsensitiveCompare:str.get()] == NSOrderedDescending; }
	oo_inline BOOL operator <= ( cOOString str ) const { return !operator > ( str ); }

	// append string
	oo_inline OOString tmpcopy() const {
		OOString tmp;
		tmp.copy( get() );
#ifndef OO_ARC ////////
        tmp.autoget();
#endif
		return tmp;// += noalloc();
	}
	oo_inline OOString operator + ( NSString *str ) const {
		return tmpcopy() += str;
	}
	oo_inline OOString operator + ( int val ) const {
		return tmpcopy() += val;
	}
	oo_inline OOString operator + ( float val ) const {
		return tmpcopy() += val;
	}
	oo_inline OOString operator + ( double val ) const {
		return tmpcopy() += val;
	}
	oo_inline OOString operator + ( cOOString str ) const {
		return operator + ( str.get() );
	}
	oo_inline OOString operator + ( const char *str ) const {
		return operator + ( OOString( str ) );
	}
	oo_inline OOString operator + ( const OOArraySub<OOString> &str ) const {
		return operator + ( str.get() );
	}
	oo_inline OOString operator + ( const OODictionarySub<OOString> &str ) const {
		return operator + ( str.get() );
	}
	oo_inline OOString operator + ( const OOArraySub<NSString *> &str ) const {
		return operator + ( str.get() );
	}
	oo_inline OOString operator + ( const OODictionarySub<NSString *> &str ) const {
		return operator + ( str.get() );
	}

#if 1
	// inplace left associative string concatenation
	oo_inline OOString &operator % ( int n ) { return *this += n; }
	oo_inline OOString &operator % ( float n ) { return *this += n; }
	oo_inline OOString &operator % ( double n ) { return *this += n; }
	oo_inline OOString &operator % ( NSString *str ) { return *this += str; }
	oo_inline OOString &operator % ( cOOString str ) { return *this += str; }
#endif

	// remove string
	oo_inline OOString operator - ( const char *val ) const {
		return operator - ( OOString( val ).get() );
	}
	oo_inline OOString operator - ( cOOString str ) const {
		return tmpcopy() -= str;
    }
	oo_inline OOString operator - ( NSString *str ) const {
		return tmpcopy() -= str;
    }
	// split by str
	oo_inline OOStringArray operator / ( cOOString sep ) const {
		OOPoolIfRequired;
		return [noalloc() componentsSeparatedByString:sep];
	}
	oo_inline OOStringArray operator / ( const OOPattern &sep ) const;

	// index into string by character number or perform search
	oo_inline OOStringSub operator [] ( int sub ) const { return OOStringSub( get(), sub ); }
    oo_inline OOStringSub operator [] ( const NSRange &sub ) const { return OOStringSub( get(), sub ); }
    oo_inline OOStringSearch operator [] ( cOOString sub ) const;
	oo_inline OOStringSearch operator [] ( const char *sub ) const;
    oo_inline OOStringSearch operator [] ( NSString *sub ) const;

    oo_inline OOString &operator <<= ( NSString *val ) { copy( (NSMutableString *)val ); return *this; }
    oo_inline OOString &operator <<= ( cOOString val ) { copy( val.get() ); return *this; }
	// &|^ bitwise operators for pattern matching - see below...
};

// replicate string 
inline OOString operator * ( cOOString str, int count ) {
	OOString out = "";
	for ( int i=0 ; i<count ; i++ )
		out += str;
	return out;
}


template <typename ETYPE>
inline OOString OOArray<ETYPE>::join( cOOString sep ) const {
	OOString out = @"";
	for ( int i=0 ; i<*this ; i++ ) {
		if ( i )
			out += sep;
		out += (*this)[i];
	}
	return out;
}

// misc forward references to OOString
template <typename ETYPE>
inline OOString operator / ( const OOArray<ETYPE> &left, cOOString sep ) {
	return left.join( sep );
}

template <typename ETYPE>
inline OOArray<ETYPE> &OOArray<ETYPE>::operator = ( const char *val ) {
    *this = OOString(val) / @" ";
    return *this;
}
template <typename ETYPE>
inline OOArray<ETYPE> &OOArray<ETYPE>::operator = ( const char **val ) {
    [alloc() removeAllObjects];
    while ( *val )
        *this += OOString( *val++ );
    return *this;
}

template <typename ETYPE>
inline OODictionary<ETYPE> &OODictionary<ETYPE>::operator = ( const char *val ) {
    *this = OOStringArray(val);
    return *this;
}
template <typename ETYPE>
inline OODictionary<ETYPE> &OODictionary<ETYPE>::operator = ( const char **val ) {
    *this = OOStringArray( val );
    return *this;
}

template <typename ETYPE>
inline OODictionarySub<ETYPE> OODictionary<ETYPE>::operator [] ( cOOString sub ) const {
    return OODictionarySub<ETYPE>( this, sub.get() );
}

template <typename ETYPE>
inline OODictionarySub<ETYPE> OODictionary<ETYPE>::operator [] ( const OOArraySub<OOString> &sub ) const {
	return OODictionarySub<ETYPE>( this, sub.get() );
}

template <typename ETYPE>
inline OODictionarySub<ETYPE> OODictionary<ETYPE>::operator [] ( const OODictionarySub<OOString> &sub ) const {
	return OODictionarySub<ETYPE>( this, sub.get() );
}

template <typename ETYPE,typename RTYPE,typename STYPE>
inline OODictionarySub<STYPE> OOSubscript<ETYPE,RTYPE,STYPE>::operator [] ( cOOString sub ) const {
    //return (*this)[sub.get()];
    return operator [] ( sub.get() );
}

template <typename ETYPE,typename RTYPE,typename STYPE>
inline OODictionarySub<STYPE> OOSubscript<ETYPE,RTYPE,STYPE>::operator [] ( const char *sub ) const {
    return (*this)[OOString(sub)];
}

template <typename ETYPE,typename RTYPE,typename STYPE>
inline OOSubscript<ETYPE,RTYPE,STYPE> &OOSubscript<ETYPE,RTYPE,STYPE>::operator <<= ( const char *val ) {
    set( OOString( val ) );
    return *this;
}

template <typename ETYPE>
inline OOArraySub<ETYPE> &OOArraySub<ETYPE>::operator = ( ETYPE val ) { set( val ); return *this; }

template <typename ETYPE>
inline OODictionarySub<ETYPE> &OODictionarySub<ETYPE>::operator = ( ETYPE val ) { set( val ); return *this; }

template <typename ETYPE>
inline OOArraySub<ETYPE> &OOArraySub<ETYPE>::operator = ( const char *val ) { *this = OOString(val).get(); return *this; }

template <typename ETYPE>
inline OODictionarySub<ETYPE> &OODictionarySub<ETYPE>::operator = ( const char *val ) { *this = OOString(val).get(); return *this; }

template <typename ETYPE>
inline OOArray<ETYPE> &OOArray<ETYPE>::operator += ( ETYPE val ) {
    [alloc() addObject:!val ? OONull : (id)val];
    return *this;
}

// initial operand in concatenation not OOString
inline OOString operator + ( NSString *left, cOOString right ) { return OOString( left )+right; }
inline OOString operator + ( NSString *left, const OOArraySub<OOString> &right ) { return OOString( left )+*right; }
inline OOString operator + ( NSString *left, const OODictionarySub<OOString> &right ) { return OOString( left )+*right; }

inline OOString operator + ( const char *left, cOOString right ) { return OOString( left )+right; }
inline OOString operator + ( const char *left, const OOArraySub<OOString> &right ) { return OOString( left )+*right; }
inline OOString operator + ( const char *left, const OODictionarySub<OOString> &right ) { return OOString( left )+*right; }

// initial operand in comparison not OOString
inline BOOL operator == ( NSString *left, cOOString right ) { return OOString( left )==right; }
inline BOOL operator != ( NSString *left, cOOString right ) { return OOString( left )!=right; }
inline BOOL operator == ( const char *left, cOOString right ) { return OOString( left )==right; }
inline BOOL operator != ( const char *left, cOOString right ) { return OOString( left )!=right; }

// string || string for default values
inline OOString operator || ( cOOString left, cOOString right ) { return !left ? right : left; }
inline OOString operator || ( cOOString left, const char *right ) { return left || OOString( right ); }

/*=================================================================================*/
/*================================ Pattern matching classes =======================*/

extern "C" {
    #include <regex.h>
}

typedef OOString (^OOReplaceBlock)( OOStringArray groups );

// "ENHANCED" regexps available to deploy on OSX 10.8/iOS 6.0+
#ifdef REG_ENHANCED
#define OO_REG_FLAGS REG_EXTENDED|REG_ENHANCED
#else
#define OO_REG_FLAGS REG_EXTENDED
#endif

/**
 A class to represent a patten matching operations against a string.
 
 Usage:
 <pre>
OOStringArray words = OOPattern( @"\\w+" ).match();
 </pre>
 */

class OOPattern {
	OOString pat;
    oo_inline OOStringArray matchGroups( const char *input, regmatch_t *matches ) const {
        OOStringArray groups;
        for ( int i=0 ; i<=regex->re_nsub ; i++ )
            groups[i] = matches[i].rm_so == -1 ? OOString( OONull ) :
                OOString( input+matches[i].rm_so, (NSUInteger)(matches[i].rm_eo-matches[i].rm_so) );
        return groups;
    }
public:
	regex_t *regex;

	oo_inline OOPattern() {}
	oo_inline OOPattern( cOOString patin, int flags = OO_REG_FLAGS ) {
        init( patin, flags );
    }
	oo_inline void init( cOOString patin, int flags );

	oo_inline int exec( const char *input, int matchmax = 0, regmatch_t matches[] = NULL, int eflags = 0 ) const {
		int error = regexec( regex, input, matchmax, matches, eflags );
		if ( error && error != REG_NOMATCH ) {
			char errbuff[1024];
			regerror( error, regex, errbuff, sizeof errbuff );
			OOWarn( @"OOPattern::exec() Regex match error: %s, in pattern'%@'", errbuff, *pat );
		}
		return error == 0;
	}

	oo_inline int find( const char *input, int matchmax, regmatch_t matches[] ) const {
		int nmatches = 0;
		for ( regoff_t pos = 0 ; exec( input+pos, matchmax-nmatches, matches+nmatches ) ; nmatches++ ) {
			matches[nmatches].rm_so += pos;
			pos = matches[nmatches].rm_eo += pos;
		}
		return nmatches;
	}
	oo_inline OOStringArray split( cOOString str ) const {
		OOPoolIfRequired;
		const char *input = str;
		OOStringArray out;

		regmatch_t matches[100];
		for ( ; exec( input, sizeof matches/sizeof matches[0], matches ) ; input += matches[0].rm_eo )
			out += OOString( input, (NSUInteger)matches[0].rm_so );

		out += OOString( input );
		return out;
	}

	oo_inline OOStringArray matchAll( cOOString str ) const {
		OOPoolIfRequired;
		const char *input = str;
		OOStringArray out;

		regmatch_t matches[100];
        for ( ; input && exec( input, sizeof matches/sizeof matches[0], matches ) ; input += matches[0].rm_eo )
            out += OOString( input+matches[0].rm_so, (NSUInteger)(matches[0].rm_eo-matches[0].rm_so) );

		return out;
	}
    
	oo_inline OOStringArray match( cOOString str ) const {
		OOPoolIfRequired;
		const char *input = str;
		OOStringArray out;

        int outerGroups[100], *oend = outerGroups;
        for ( int ptr = 0, group = 0, level = 0 ; regex->re_nsub && ptr < [pat length] &&
             oend < outerGroups+sizeof outerGroups/sizeof outerGroups[0] ; ptr++ )
            switch( pat[ptr] ) {
                case '(':
                    if ( ++group && ++level == 1 )
                        *oend++ = group;
                    break;
                case ')': --level; break;
                case '\\': ptr++; break;
            }

        if ( oend == outerGroups )
            return matchAll( str );

		regmatch_t matches[100];
        for ( ; input && exec( input, sizeof matches/sizeof matches[0], matches ) ; input += matches[0].rm_eo )
            for ( int *optr = outerGroups ; optr<oend ; optr++ )
                out += matches[*optr].rm_so == -1 ? OOString( OONull ) :
                OOString( input+matches[*optr].rm_so,
                         (NSUInteger)(matches[*optr].rm_eo-matches[*optr].rm_so) );

		return out;
	}
    
	oo_inline OOStringArray parse( cOOString str ) const {
		OOPoolIfRequired;
		const char *input = str;
		OOStringArray out;

		regmatch_t matches[100];
		if ( exec( input, sizeof matches/sizeof matches[0], matches ) )
			out = matchGroups( input, matches );

		return out;
	}
	oo_inline OOStringArrayArray parseAll( cOOString str ) const {
		OOPoolIfRequired;
		const char *input = str;
        OOStringArrayArray out;

		regmatch_t matches[100];
		for ( ; exec( input, sizeof matches/sizeof matches[0], matches ) ; input += matches[0].rm_eo )
            out += matchGroups( input, matches );

		return out;
	}
	oo_inline OOString blockReplace( cOOString str, OOReplaceBlock callback ) const {
		OOPoolIfRequired;
		const char *input = str;
		OOString out;

		regmatch_t matches[100];
		for ( ; exec( input, sizeof matches / sizeof matches[0], matches ) ; input += matches[0].rm_eo )
            out += OOString( input, (NSUInteger)matches[0].rm_so )+callback( matchGroups( input, matches ) );

		return out += OOString( input );
	}
};

// array of matches in string
inline OOStringArray operator & ( cOOString str, const OOPattern &pattern ) { return pattern.matchAll( str ); }
inline OOStringArray operator & ( cOOString str, const OOPattern *pattern ) { return str & *pattern; }
inline OOStringArray operator & ( cOOString str, const OOString  &patexpr ) { return str & OOPattern( patexpr ); }

// groups found in single match
inline OOStringArray operator ^ ( cOOString str, const OOPattern &pattern ) { return pattern.parse( str ); }
inline OOStringArray operator ^ ( cOOString str, const OOPattern *pattern ) { return str ^ *pattern; }
inline OOStringArray operator ^ ( cOOString str, const OOString  &patexpr ) { return str ^ OOPattern( patexpr ); }

inline OOStringArray OOString::operator / ( const OOPattern &sep ) const {
	return sep.split( *this );
}


class OOReplace {
	regmatch_t dmatches[100];
	OOPattern pattern;
	OOString replace;
	int dollarCount;

    oo_inline OOPattern *dollarPattern() const {
        static OOPattern *dollarPattern;
		if ( !dollarPattern )
			dollarPattern = new OOPattern( "\\\\\\$|\\$[[:digit:]]+|\\${[[:digit:]]+}" );
        return dollarPattern;
    }

    void expandDollars( const char *input, const regmatch_t matches[100], const char *dstr, OOString &out ) const {
        regoff_t pos = 0;
        out += OOString( input, (NSUInteger)matches[0].rm_so );

        for ( int d=0 ; d<dollarCount ; d++ ) {
            out += OOString( dstr+pos, (NSUInteger)(dmatches[d].rm_so-pos) );
            const char *vptr = dstr+dmatches[d].rm_so+1;
            int v = atoi( *vptr == '{' ? vptr+1 : vptr );
            out += *vptr == '$' ? OOString( vptr, 1 ) :
                OOString( input+matches[v].rm_so, (NSUInteger)(matches[v].rm_eo-matches[v].rm_so) );
            pos = dmatches[d].rm_eo;
        }

        out += OOString( dstr+pos );
    }

public:
	oo_inline OOReplace() {}
	oo_inline OOReplace( const char *expr ) {
		init( expr );
	}
	oo_inline OOReplace( cOOString expr ) {
		init( expr );
	}
	oo_inline OOReplace( cOOString pat, cOOString rep, int flags = OO_REG_FLAGS ) {
		init( pat, rep, flags );
	}

	oo_inline void init( cOOString expr ) {
		OOPool pool;
		OOStringArray split = expr / expr[NSMakeRange(0,1)];
		int flags = OO_REG_FLAGS;

		for ( const char *options = *split[3] ; *options ; options++ )
			switch ( *options ) {
				case 'i': flags |= REG_ICASE; break;
				case 'm': flags |= REG_NEWLINE; break;
			}

		init( *split[1], *split[2], flags );
	}
	oo_inline void init( cOOString pat, cOOString rep, int flags = OO_REG_FLAGS ) {
		pattern.init( pat, flags );
		OOPool pool;
        if ( !!rep )
            dollarCount = dollarPattern()->find( replace <<= rep, sizeof dmatches / sizeof dmatches[0], dmatches );
	}

	oo_inline OOString exec( const char *input ) const {
		OOPoolIfRequired;
		const char *dstr = replace;
		regmatch_t matches[100];
		OOString out;
    
		for ( ; pattern.exec( input, sizeof matches / sizeof matches[0], matches ) ; input += matches[0].rm_eo )
            expandDollars( input, matches, dstr, out );
    
		return out += OOString( input );
	}
	oo_inline OOString exec( const char *input, cOOStringArray outputs ) {
		OOPoolIfRequired;
		regmatch_t matches[100];
		OOString out;
    
		for ( int i=0 ; 
             pattern.exec( input, sizeof matches / sizeof matches[0], matches ) && i < outputs ; 
             input += matches[0].rm_eo, i++ ) {
            const char *dstr = outputs[i];
            dollarCount = dollarPattern()->find( dstr, sizeof dmatches / sizeof dmatches[0], dmatches );
            expandDollars( input, matches, dstr, out );
		}
    
		return out += OOString( input );
	}

};

// apply replacement string e.g. @"/a/b/"
inline OOString operator | ( cOOString str, const OOReplace &replace ) { OOPoolIfRequired; return replace.exec( str ); }
inline OOString operator | ( cOOString str, const OOReplace *replace ) { return str | *replace; }
inline OOString operator | ( cOOString str, const OOString  &patrepl ) { return str | OOReplace( patrepl ); }

// ... inplace
inline OOString &operator |= ( OOString &str, const OOReplace &replace ) { return str = str | replace; }
inline OOString &operator |= ( OOString &str, const OOReplace *replace ) { return str = str | replace; }
inline OOString &operator |= ( OOString &str, const OOString  &patrepl ) { return str = str | patrepl; }

/**
 A class to represent a C pointer inside an NSValue object for ref counting and
 so it can be stored inside the OSX buffs NSDictionary etc.
 
 Usage:
 <pre>
 OOPointer<void *> ptr = malloc(1000);
 void *p = ptr;
 </pre>
 */

template <typename PTYPE>
class OOPointer : public OOReference<NSValue *> {
	PTYPE ptr;
protected:
	oo_inline NSValue *pset( NSValue *val ) OO_RETURNS {
		// recover pointer from NSValue object
		set( val );
		ptr = val == OONull || ![val respondsToSelector:@selector(pointerValue)] ?
                                                        NULL : (PTYPE)[val pointerValue];
		return val;
	}
	oo_inline PTYPE pset( PTYPE ptr ) {
		// store pointer in NSValue objects so it can be referrence counted
		OO_RELEASE( pset( [[NSValue alloc] initWithBytes:&ptr objCType:@encode(PTYPE)] ) );
		return ptr;
	}
	oo_inline PTYPE pget() {
		return !*this ? NULL : ptr;
	}
public:
	oo_inline OOPointer() { }
	oo_inline OOPointer( PTYPE ptr ) { *this = ptr; }
	oo_inline OOPointer( NSValue *val ) { *this = val; }
	oo_inline OOPointer( const OOPointer &val ) { *this = val; }

	oo_inline operator PTYPE () { return pget(); }
	oo_inline PTYPE operator * () { return pget(); }
	oo_inline PTYPE operator -> () { return pget(); }

	oo_inline OOPointer &operator = ( PTYPE ptr ) { pset( ptr ); return *this;	}
	oo_inline OOPointer &operator = ( NSValue *val ) { pset( val ); return *this; }
	oo_inline OOPointer &operator = ( const OOPointer &val ) { pset( val.get() ); return *this; }
};


/**
 Initialisation for OOPattern class. Replaces \[wWdWsS] with character classes 
for compatability with perl. All compiled reguar expressions are cached.
 */

static OOArray<OOPointer<regex_t *> > cache;

inline void OOPattern::init( cOOString patin, int flags ) {
    if ( !patin )
        OOWarn( @"OOPattern::init - nil pattern passed" );

    pat <<= patin.get();

	if ( !!cache[flags][patin] ) {
		regex = *cache[flags][patin];
		return;
	}

#ifndef REG_ENHANCED
    OOPool pool;
	static BOOL patfix;

	if ( !patfix ) {
		static const char *shortcuts[] = {
			"w/$1[[:alnum:]]/", "W/$1[^[:alnum:]]/",
			"d/$1[[:digit:]]/", "D/$1[^[:digit:]]/",
			"s/$1[[:space:]]/", "S/$1[^[:space:]]/"};
		static int nfixes = sizeof shortcuts/sizeof *shortcuts;
		static OOReplace patternShortcuts[sizeof shortcuts/sizeof *shortcuts];

        static int donePatterns;
		if ( !patternShortcuts || !donePatterns++ ) {
			int savefix = patfix;
			patfix = YES;
			for ( int i=0 ; i<nfixes ; i++ )
				patternShortcuts[i].init( OOString( @"/(^|[^\\\\](\\\\\\\\)*)\\\\" )+shortcuts[i] );
			patfix = savefix;
		}

		for ( int i=0 ; i<nfixes ; i++ )
			pat |= patternShortcuts[i];
	}
#endif

	regex = new regex_t;
	int error = regcomp( regex, pat, flags );
	if ( error ) {
		char errbuff[1024];
		regerror( error, regex, errbuff, sizeof errbuff );
		OOWarn( @"OOPattern::init() Regex compilation error: %s, in pattern: \"%@\"", errbuff, *pat );
		delete regex;
	}
	else
		cache[flags][patin] = regex;
}

/**
 Internal class representing subscript by string which performs a search into the
 string. Assigning to for example str[@"BARRY"] = @"BAZ" will change all occurances
 of "BARRY" in the string to "BAZ".

 Usage:
 <pre>
 OOString str <<= @"BARRY is great";
 str[@"great"] = @"an egotist";
 </pre>
 */

/**
 A class to represent a match and replace operations against a string.
 uses BSD regex documented in "man regex"

 Usage:
 <pre>
 OOString quoted = OOReplace( @"/(\\w+)/'$1'/" ).exec();
 </pre>
 */

class OOStringSearch {
    friend class OOString;
    OOString *str, idx;
    oo_inline OOStringSearch( const OOString *ref, cOOString sub ) {
        str = (OOString *)ref;
        idx = sub;
    }

public:
    oo_inline OOPattern pattern() const {
        return OOPattern( idx );
    }
    oo_inline NSRange range() const {
        regmatch_t match;
        NSRange range = {NSNotFound, 0};
        const char *input = *str;

        if ( pattern().exec( input, 1, &match ) ) {
            range.location = [OOString( input, (int)match.rm_so ) length];
            range.length = [OOString( input+match.rm_so, (int)(match.rm_eo-match.rm_so) ) length];
        }

        return range;
    }
    oo_inline operator NSRange () const {
        return range();
    }
	oo_inline operator NSUInteger () const {
		return range().location;
	}
    oo_inline BOOL operator ! () const {
        return !*str || !pattern().exec( *str );
    }
    oo_inline NSRange operator & () const {
        return range();
    }

    oo_inline OOString operator * () const {
        NSRange r = range();
        return r.location != NSNotFound ? [*str substringWithRange:r] : nil;
    }
    oo_inline operator OOString () const {
        return **this;
    }

    oo_inline OOStringArray match() const {
        return pattern().match( *str );
    }

    oo_inline operator OOStringArray () const {
        return match();
    }
    oo_inline operator OOStringArrayArray () const{
        return pattern().parseAll( *str );
    }

    oo_inline OOString &operator = ( NSString *replacement ) {
        OOReplace replacer( idx, replacement );
        *str = replacer.exec( *str );
        return *str;
    }
    oo_inline OOString &operator = ( const char *replacement ) {
        return *this = *OOString( replacement );
    }
    oo_inline OOString &operator = ( OOStringArray replacements ) {
        OOReplace replacer( idx, nil );
        *str = replacer.exec( *str, replacements );
        return *str;
    }
    oo_inline OOString &operator = ( OOReplaceBlock callback ) {
        *str = pattern().blockReplace( *str, callback );
        return *str;
    }

    oo_inline OOString operator [] ( int group ) const {
        return pattern().match( *str )[group];
    }
    oo_inline OOStringArray operator ~ () {
        OOStringArray match = pattern().parse( *str );
        (*str)[idx] = OOStringArray( @"", nil );
        return match;
    }
};

inline OOStringSearch OOString::operator [] ( cOOString sub ) const {
    return OOStringSearch( this, sub );
}
inline OOStringSearch OOString::operator [] ( NSString *sub ) const {
    return OOStringSearch( this, sub );
}
inline OOStringSearch OOString::operator [] ( const char *sub ) const {
    return OOStringSearch( this, sub );
}

template <typename ETYPE>
inline OOArray<ETYPE> &OOArray<ETYPE>::operator = ( const OOStringSearch &search ) {
    return *this = search.match();
}

template <typename ETYPE>
inline OODictionary<ETYPE> &OODictionary<ETYPE>::operator = ( const OOStringSearch &search ) {
    return *this = search.match();
}

inline OOString &OOString::operator -= ( cOOString str ) {
    alloc();
    (*this)[str] = @"";
    return *this;
} ////

/**
 Assign to up to 10 variables directly from an array.
 */

#define OOVars( _type, _vars... ) _type _vars; OOAssign<_type>( _vars )
#define OOStringVars( _vars... ) OOVars( OOString, _vars )
#define OOStringAssign OOAssign<OOString>

template <typename ETYPE>
class OOAssign {
    ETYPE *vars[10];
public:
    oo_inline OOAssign( ETYPE &v0,
                       ETYPE &v1 = *(ETYPE *)NULL, ETYPE &v2 = *(ETYPE *)NULL, ETYPE &v3 = *(ETYPE *)NULL,
                       ETYPE &v4 = *(ETYPE *)NULL, ETYPE &v5 = *(ETYPE *)NULL, ETYPE &v6 = *(ETYPE *)NULL,
                       ETYPE &v7 = *(ETYPE *)NULL, ETYPE &v8 = *(ETYPE *)NULL, ETYPE &v9 = *(ETYPE *)NULL ) {
        vars[0] = (ETYPE *)v0.ptr();
        vars[1] = (ETYPE *)v1.ptr(); vars[2] = (ETYPE *)v2.ptr(); vars[3] = (ETYPE *)v3.ptr();
        vars[4] = (ETYPE *)v4.ptr(); vars[5] = (ETYPE *)v5.ptr(); vars[6] = (ETYPE *)v6.ptr();
        vars[7] = (ETYPE *)v7.ptr(); vars[8] = (ETYPE *)v8.ptr(); vars[9] = (ETYPE *)v9.ptr();
    }
    oo_inline OOArray<ETYPE> operator = ( const OOArray<ETYPE> &in ) {
        for ( int i=0 ; vars[i] && i<sizeof vars/sizeof vars[0] ; i++ )
            if ( i<[in count] )
                *vars[i] = in[i];
            else
                *vars[i] = OONil;
        return in;
    }
};

/*=================================================================================*/
/*================================ Utility classes ================================*/

static jmp_buf oo_jmp_env;

static void oo_trapper( int sig ) {
	NSLog( @"SIGNAL %d", sig );
	longjmp( oo_jmp_env, 1 );
}

inline int OOTrap() {
	signal( SIGSEGV, oo_trapper );
	signal( SIGBUS, oo_trapper );
	return setjmp( oo_jmp_env );
}

/**
 Network request on which you can POST data or set HTP header values.
 */

class OORequestSub;
class OORequest : public OOReference<NSMutableURLRequest *> {
public:
	NSURLResponse *theResponse;
	NSError *error;

	oo_inline OORequest() {}
	oo_inline OORequest( NSURL *url, 
						NSURLRequestCachePolicy cachePolicy = NSURLRequestUseProtocolCachePolicy, 
						NSTimeInterval timeoutInterval = 60. ) {
		rawset( [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:cachePolicy
                                         timeoutInterval:timeoutInterval] );
	}
	oo_inline OORequest( cOOString url ) {
		NSURL *URL = [[NSURL alloc] initWithString:url];
		rawset( [[NSMutableURLRequest alloc] initWithURL:URL] );
		OO_RELEASE( URL );
	}
	oo_inline OORequest( const OORequest &req ) {
		set( req.get() );
	}

	oo_inline OORequest &operator = ( NSURLRequest *val ) { 
		set( (id)val ); return *this; /////
	}
	oo_inline OORequestSub operator [] ( cOOString sub );
	oo_inline OORequest &post( NSData *data ) {
		[get() setHTTPMethod:@"POST"];
        [get() setValue:OOFormat( @"%d", (int)[data length] )
            forHTTPHeaderField:@"Content-Length"];
		[get() setHTTPBody:data];
		return *this;
	}
	oo_inline OORequest &post( cOOString str, NSStringEncoding encoding = NSUTF8StringEncoding ) {
        [get() setValue:@"application/x-www-form-urlencoded"
            forHTTPHeaderField:@"Content-Encoding"];
		post( [urlEncode( str ) dataUsingEncoding:encoding allowLossyConversion:YES] );
		return *this;
	}

    oo_inline NSString *urlEncode( NSString *text ) {
		NSMutableString *encoded = [NSMutableString string];
		for ( const char *iptr = [text UTF8String] ; iptr && *iptr ; iptr++ )
			if ( *iptr > 0 ) ///
				[encoded appendFormat:@"%c", *iptr];
			else
				[encoded appendFormat:@"%%%02x", *iptr&0xff];

		return encoded;
	}

	oo_inline OOData data() {
        [[NSURLCache sharedURLCache] removeCachedResponseForRequest:get()];
#ifndef OO_ARC
        return [NSURLConnection sendSynchronousRequest:get() returningResponse:&theResponse error:&error];
#else
        NSURLResponse *tmpResponse; NSError *tmpError;
		OOData data = [NSURLConnection sendSynchronousRequest:get() returningResponse:&tmpResponse error:&tmpError];
        theResponse = tmpResponse; error = tmpError;
        return data;
#endif
	}
	oo_inline OOString string( NSStringEncoding *encoding = NULL ) {
		////OOPool pool;
        OOData data = this->data();
		NSString *textEncoding = [theResponse textEncodingName];
		CFStringEncoding coreEncoding = textEncoding ?
            CFStringConvertIANACharSetNameToEncoding( OO_BRIDGE(CFStringRef)textEncoding ) : 
            kCFStringEncodingUTF8;
        NSStringEncoding tmp; if ( !encoding ) encoding = &tmp;
		*encoding = CFStringConvertEncodingToNSStringEncoding( coreEncoding );
        return OOString( data, *encoding );
	}
    oo_inline operator OOString () {
        return string();
    }
};

class OORequestSub {
	friend class OORequest;
    OORequest *req;
	OOString key;

	oo_inline OORequestSub( OORequest *req, cOOString key ) {
		this->req = req;
		this->key = key;
	}

public:
    oo_inline OORequestSub operator = ( cOOString val ) {
        [req->get() setValue:val forHTTPHeaderField:key];
        return *this;
    }
    oo_inline operator OOString () {
        return [req->get() valueForHTTPHeaderField:key];
    }
};

inline OORequestSub OORequest::operator [] ( cOOString sub ) {
    return OORequestSub( this, sub );
}

/**
 OOURL to initialise strings from the network or files.
 */

class OOURL : public OOReference<NSURL *> {
public:

	oo_inline OOURL( NSString *url = OONil ) {
		setURL( url );
	}
	oo_inline OOURL( cOOString url ) {
		setURL( url );
	}
	oo_inline void setURL( cOOString url ) {
		if ( !!url )
			rawset( [[NSURL alloc] initWithString:url] );
	}
	oo_inline OORequest request() const {
		return OORequest( get() );
	}
	oo_inline OOString string( NSStringEncoding *encoding = NULL ) const {
        return request().string( encoding );
	}
	oo_inline OOData data() const {
        return request().data();
	}
    oo_inline operator OOString () const {
        return string();
    }
    oo_inline operator OOData () const {
        return data();
    }
	oo_inline id object() {
		return [NSKeyedUnarchiver unarchiveObjectWithData:data()];
	}
	oo_inline OOString post( cOOString post ) {
		return request().post( post );
	}
	OONode xml( int flags = 0 );
};

/**
 Placeholder for a file path, see OOResource, OODocument, OOTmpFile.
 */

class OOFile : public OOURL {
#ifdef __OBJC_GC__
    NSURL *ref3;
	oo_inline virtual id rawset( NSURL *val ) OO_RETURNS {
		return OOReference<NSURL *>::rawset( ref3 = val );
	}
#endif
public:
    oo_inline OOFile() {
    }
	oo_inline OOFile( cOOString path ) : OOURL( OONil ) {
		setPath( path );
	}
	oo_inline OOFile( cOOString name, cOOString type ) : OOURL( OONil ){
		setPath( [[NSBundle mainBundle] pathForResource:name ofType:type] );
	}
	oo_inline OOFile &setPath( cOOString path ) {
		if ( *path )
			rawset( [[NSURL alloc] initFileURLWithPath:path.get()] );
        return *this;
	}
	oo_inline OOString path() const {
		return [get() path];
	}
	oo_inline OOString name() const {
		return [path() lastPathComponent];
	}
    oo_inline OOString directory() const {
        return [path() stringByDeletingLastPathComponent];
    }
    oo_inline OOFile &canonize() {
        return setPath( [path() stringByResolvingSymlinksInPath] );
    }
	oo_inline NSDictionary *attr( NSError **error = NULL ) const {
		return [[NSFileManager defaultManager] attributesOfItemAtPath:path() error:error];
	}
	oo_inline unsigned long long size() const {
		return [attr() fileSize];
	}

	oo_inline BOOL exists() const {
		return [[NSFileManager defaultManager] fileExistsAtPath:path()];
	}
    oo_inline BOOL copyto( cOOString to ) {
        return [[NSFileManager defaultManager] copyItemAtPath:path() toPath:to error:NULL];
    }
    oo_inline BOOL moveto( cOOString to ) {
        return [[NSFileManager defaultManager] moveItemAtPath:path() toPath:to error:NULL];
    }
    oo_inline BOOL linkto( cOOString to ) {
        return [[NSFileManager defaultManager] linkItemAtPath:path() toPath:to error:NULL];
    }
	oo_inline BOOL remove() {
		return [[NSFileManager defaultManager] removeItemAtPath:path() error:NULL];
	}
    oo_inline BOOL mkdir( BOOL flag = YES, NSDictionary *attr = nil ) {
        return [[NSFileManager defaultManager] createDirectoryAtPath:path()
                                         withIntermediateDirectories:flag attributes:attr error:NULL];
    }
	oo_inline BOOL save( cOOString string, NSStringEncoding encoding = NSUTF8StringEncoding ) {
		return save( [string dataUsingEncoding:encoding allowLossyConversion:YES] );
	}
	oo_inline BOOL save( const NSData *data, BOOL atomically = NO ) {
		return [data writeToFile:path() atomically:atomically];
	}
	oo_inline BOOL save( id object ) {
		return save( [NSKeyedArchiver archivedDataWithRootObject:object] );
	}
    oo_inline OOFile &operator = ( cOOString str ) {
        save( str ); return *this;
    }
    oo_inline OOFile &operator = ( const OOData &data ) {
        save( *data ); return *this;
    }
    oo_inline OOFile &operator = ( const OOFile &file ) {
        return *this = file.data();
    }
#if 000
    oo_inline BOOL operator ! () const {
        return !exists();
    }
    oo_inline BOOL operator ~ () {
        return remove();
    }
#endif
};

/**
 Pathfinder for resources in applications.
 */

class OOResource : public OOFile {
public:
	oo_inline OOResource( cOOString name ) : OOFile( OOString( OONil ) ) {
		OOStringArray comps = name / @".";
		setPath( [[NSBundle mainBundle] pathForResource:**comps[0]
												 ofType:comps>1 ? **comps[1] : nil] );
	}
};

/**
 Pathfinder for documents for applications.
 */

class OODocument : public OOFile {
public:
	oo_inline OODocument( cOOString name ) :
        OOFile( OOFormat( @"%@/Documents/%@", NSHomeDirectory(), *name ) ) {}
};

/**
 Pathfinder for temporary files for applications.
 */

class OOTmpFile : public OOFile {
public:
	oo_inline OOTmpFile( cOOString name ) :
        OOFile( OOFormat( @"%@/tmp/%@", NSHomeDirectory(), *name ) ) {}
};

/**
 Internal class for subscripted acces to defaults.
 */

class OODefaultsSub : public OODictionarySub<OOString> {
	friend class OODefaults;
	oo_inline OODefaultsSub( const OODictionary<OOString> *root, id key ) : OODictionarySub<OOString>( root, key ) {
	}
	oo_inline virtual id get( BOOL warn = YES ) const OO_RETURNS {
		id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
        if ( [value class] == [NSArray class] ||
            [value class] == [NSDictionary class] )
            OO_RELEASE( set( value = [value mutableCopy] ) );
        else
            OODictionarySub<OOString>::set( value );
		return value != OONull ? value : nil;
	}
	oo_inline virtual id set ( id value ) const OO_RETURNS {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:value forKey:key];
        /////[defaults synchronize];
		return OODictionarySub<OOString>::set( value );
	}
public:
	oo_inline OODefaultsSub &operator = ( OOString val ) { set( val ); return *this; }
	oo_inline OODefaultsSub &operator = ( CFStringRef val ) { set( OO_BRIDGE(id)val ); return *this; }
	oo_inline OODefaultsSub &operator = ( NSString *val ) { set( val ); return *this; }
	oo_inline OODefaultsSub &operator = ( NSArray *val ) { set( val ); return *this; }
	oo_inline OODefaultsSub &operator = ( NSDictionary *val ) { set( val ); return *this; }
	oo_inline OODefaultsSub &operator = ( long long val ) { set( [[NSNumber numberWithLongLong:val] stringValue] ); return *this; }
	oo_inline OODefaultsSub &operator = ( double val ) { set( [[NSNumber numberWithDouble:val] stringValue] ); return *this; }
	oo_inline OODefaultsSub &operator = ( float val ) { set( [[NSNumber numberWithFloat:val] stringValue] ); return *this; }
	oo_inline OODefaultsSub &operator = ( int val ) { set( [[NSNumber numberWithInt:val] stringValue] ); return *this; }
	oo_inline OODefaultsSub &operator = ( BOOL val ) { set( [[NSNumber numberWithBool:val] stringValue] ); return *this; }

	oo_inline operator long long () { return [get() longLongValue]; }
	oo_inline operator double () { return [get() doubleValue]; }
	oo_inline operator float () { return [get() floatValue]; }
	oo_inline operator BOOL () { return [get() boolValue]; }
	oo_inline operator int () { return [get() intValue]; }
	oo_inline operator NSDictionary * () { return get(); }
	oo_inline operator NSString * () { return get(); }
	oo_inline operator NSArray * () { return get(); }

	oo_inline OODefaultsSub &operator = ( long val ) { set( [[NSNumber numberWithLong:val] stringValue] ); return *this; }
	oo_inline operator long () { return [get() intValue]; }

	oo_inline OOString operator ~ () {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
		return OODictionarySub<OOString>::operator ~ ();
	}
};

/**
 Binds defaults to an OODictionary.
 */

class OODefaults : public OODictionary<OOString> {
#ifdef __OBJC_GC__
    NSMutableDictionary *ref3;
	oo_inline virtual id rawset( NSMutableDictionary *val ) OO_RETURNS {
		return OOReference<NSMutableDictionary *>::rawset( ref3 = val );
	}
#endif
public:
	oo_inline OODefaults() {
		OOPool pool;
		rawset( [[[NSUserDefaults standardUserDefaults] dictionaryRepresentation] mutableCopy] );
	}
	oo_inline OODefaultsSub operator[] ( id key ) const {
		return OODefaultsSub( this, key );
	}
	oo_inline OODefaultsSub operator[] ( cOOString key ) const {
		return OODefaultsSub( this, key );
	}
	oo_inline OODefaultsSub operator [] ( const CFStringRef sub ) const {
		return (*this)[OO_BRIDGE(id)sub];
	}
	oo_inline void sync() {
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	oo_inline ~OODefaults()  {
		sync();
	}
};

/**
 Binds application's Info.plist to an OODictionary.
 */

class OOInfo : public OODictionary<OOString> {
public:
	oo_inline OOInfo() {
		set( (NSMutableDictionary *)[[NSBundle mainBundle] infoDictionary] );
	}
};

/**
 Wrapper for execution of command
 */

class OOTask {
public:
    int standardInput, pid;
    FILE *exec( cOOStringArray command ) {
        char const *argv[100], *envp[1000], **eptr = envp;

        for ( int i=0 ; i<command ; i++ )
            argv[i] = command[i];
        argv[command] = NULL;

        int input[2], output[2];
        if ( pipe( input ) < 0 || pipe( output ) < 0 )
            NSLog( @"OOTask::exec - pipe() problem" );

        if ( (pid = fork()) == 0 ) {

            FILE *fp = popen( "/usr/bin/perl -e 'print \"$_=$ENV{$_}\\n\" foreach keys %ENV; exit 99;'", "r" );
            if ( fp ) {
                char line[10000];
                while( fp && fgets( line, sizeof line, fp ) ) {
                    line[strlen(line)-1] = '\000';
                    *eptr++ = strdup(line);
                }
                if ( pclose( fp )>>8 != 99 )
                    exit( 99 );
            }
            *eptr++ = NULL;

            // close parent pipes
            close( input[1] );
            close( output[0] );

            // setup stdin/stdout/stderr
            close( 0 ); dup( input[0] ); close( input[0] );
            close( 1 ); dup( output[1] );
            close( 2 ); dup( output[1] ); close( output[1] );

            if ( execve( argv[0], (char * const *)argv, (char * const *)envp ) < 0 )
                NSLog( @"OOTask::exec - execve failed" );
            exit(1);
        }

        close( input[0] );
        close( output[1] );

        standardInput = input[1];
        return fdopen( output[0], "r" );
    }
    ssize_t send( OOData input ) {
        ssize_t wrote = write( standardInput, [input bytes], [input length] );
        close( standardInput );
        standardInput = -1;
        return wrote;
    }
    int wait() {
        if ( standardInput >= 0 )
            close( standardInput );
        int status = 1;
        if ( waitpid(pid,&status,0) < 0 )
            NSLog( @"OOTask::exec - wait problem" );
        return status;
    }
};

#if __MAC_OS_X_VERSION_MIN_REQUIRED  >= __MAC_10_7 \
|| __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_5_0
class OOJson : public OODictionary<OOString> {
public:
    OOJson( const OOData &data ) {
        *this = data;
    }
    OOJson( const OODictionary<OOString> &dict ) {
        *this = dict;
    }
    OOJson &operator = ( const OOData &data ) {
        set( [NSJSONSerialization JSONObjectWithData:data
              options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves error:NULL] );
        return *this;
    }
    OOData data() {
        return [NSJSONSerialization dataWithJSONObject:get() options:NSJSONWritingPrettyPrinted error:NULL];
    }
};
#endif

/*=================================================================================*/
/*================================ Leftovers ======================================*/

/**
 Shortcut for creating alerts.
 */

inline NSInteger OOAlert( OOString msg, id del = nil,
                            OOString cancel = @"OK", OOString b1 = nil, OOString b2 = nil ) {
#ifdef APPKIT_EXTERN
    return [[NSAlert alertWithMessageText:*OOInfo()[kCFBundleNameKey]
                            defaultButton:cancel alternateButton:b1 otherButton:b2
                informativeTextWithFormat:@"%@", *msg] runModal];
#else
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    UIAlertView *alert = [[UIAlertView alloc] 
                           initWithTitle:*OOInfo()[@"CFBundleDisplayName"] message:msg delegate:del
                           cancelButtonTitle:cancel otherButtonTitles:*b1, *b2, nil];
                          [alert show];
    OO_RELEASE( alert );
#else
    NSLog( @"OOAlert: %@", *msg );
#endif
    return 0;
#endif
}

/**
 A wrapper for a number using NSNumber so it can be put in an NSArray or NSDictionary
 */

class OONumber : public OOReference<NSNumber *> {
public:
	oo_inline OONumber( double d ) {
		rawset( [[NSNumber alloc] initWithDouble:d] );
	}
	oo_inline OONumber( NSNumber *val ) {
		set( val );
	}

	oo_inline operator NSNumber * () const { return get(); } 
	oo_inline operator double () const { return [get() doubleValue]; } 
	oo_inline double operator * () const { return [get() doubleValue]; }

	oo_inline OONumber &operator = ( const OONumber &val ) { set( val.get() ); return *this; }
	oo_inline OONumber &operator += ( double val ) { return *this = *this + val; }
	oo_inline OONumber &operator -= ( double val ) { return *this = *this - val; }
	oo_inline OONumber &operator *= ( double val ) { return *this = *this * val; }
	oo_inline OONumber &operator /= ( double val ) { return *this = *this / val; }
	oo_inline OONumber operator + ( double val ) const { return **this + val; }
	oo_inline OONumber operator - ( double val ) const { return **this - val; }
	oo_inline OONumber operator * ( double val ) const { return **this * val; }
	oo_inline OONumber operator / ( double val ) const { return **this / val; }
};

/**
 A fledgling wrapper for NSScanner which didn't really pan out...
 */

class OOScan {
	OOReference<NSScanner *> scan;
public:
	oo_inline OOScan( cOOString input ) {
		OO_RELEASE( *(scan = [[NSScanner alloc] initWithString:input]) );
	}

	oo_inline OOString operator & ( NSString *str ) {
		NSString *out = nil;
		[*scan scanString:str intoString:&out];
		return out;
	}
	oo_inline OOString operator | ( NSString *str ) {
		NSString *out = nil;
		[*scan scanUpToString:str intoString:&out];
		return out;
	}
	oo_inline OOScan &operator >> ( double &d ) {
		[*scan scanDouble:&d];
		return *this;
	}
	oo_inline OOScan &operator >> ( float &f ) {
		[*scan scanFloat:&f];
		return *this;
	}
	oo_inline OOScan &operator >> ( int &i ) {
		[*scan scanInt:&i];
		return *this;
	}
};

#endif
#endif
