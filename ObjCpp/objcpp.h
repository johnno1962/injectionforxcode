/*
 *  objcpp.h - reference counting wrappers for Objective-C containers.
 *  ========
 *
 *  Created by John Holdsworth on 01/04/2009.
 *  Copyright 2009 © John Holdsworth. All Rights Reserved.
 *
 *  $Id: //depot/ObjCpp/objcpp.h#102 $
 *  $DateTime: 2012/09/28 01:16:48 $
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

#ifndef _objcpp_h_
#define _objcpp_h_

#include <Foundation/Foundation.h>

/************************************************************************
  Add the following to your project's "Other Sources/Project_Prefix.pch"
 ************************************************************************
 
 // precompile objcpp //
#import "objcpp.h"
#import "objsql.h"

 */

// Automatic referrence counting support
#ifdef __clang__
#if __has_feature(objc_arc)
#define OO_ARC
#endif
#endif

// Used to write code that compiles both with and without ARC
#ifdef OO_ARC
#define OO_RETAIN( _obj ) _obj
#define OO_RETAINCOUNT( _obj ) (NSUInteger)-1
#define OO_AUTORELEASE( _obj ) _obj
#define OO_RELEASE( _obj ) (void)(_obj)
#define OO_DEALLOC( _obj )
#define OO_BRIDGE( _type ) (__bridge _type)
#define OO_AUTORETURNS __attribute((ns_returns_autoreleased))
#define OO_RETURNS __attribute((ns_returns_retained))
#define OO_UNSAFE __unsafe_unretained
#define OO_STRONG __strong
#define OO_WEAK _weak
#else
#define OO_RETAIN( _obj ) [_obj retain]
#define OO_RETAINCOUNT( _obj ) [_obj retainCount]
#define OO_AUTORELEASE( _obj ) [_obj autorelease]
#define OO_RELEASE( _obj ) [_obj release]
#define OO_DEALLOC( _obj ) [_obj dealloc]
#define OO_BRIDGE( _type ) (_type)
#define OO_AUTORETURNS
#define OO_RETURNS
#define OO_UNSAFE
#define OO_STRONG
#define OO_WEAK
#endif

#ifdef __cplusplus
/*===========================================================================*/
/*============================== Overrides ==================================*/

/**
 For detailed debugging
 */

#ifndef OOTrace
#ifdef OODEBUG
static struct { BOOL trace; } _objcpp = {NO};
#define OOTrace if( _objcpp.trace ) NSLog
#else
#define OOTrace if(0) NSLog
#endif
#define OORetain OOTrace
#define OORelease OOTrace
#endif

/**
 Function to log warning messages
 */

#ifndef OOWarn
#ifdef OODEBUG
#define OOWarn OODump
#else
#define OOWarn NSLog
#endif
#endif

/**
 Inital value for uninitialised references. Use (id)kCFNull to detect messaging of unititialsed objects.
 */

#ifndef OOEmpty
#ifdef OOSTRICT
#define OOEmpty (id)kCFNull
#else
#define OOEmpty nil
#endif
#endif

/**
 Value to use in place of nil in NSArray and NSDictioanry. Set to nil to trap attempts to assign nil.
 */
 
#ifndef OONoValue
#ifdef OODEBUG_NOVALUE
#define OONoValue nil
#else
#define OONoValue (id)kCFNull
#endif
#endif

#ifdef OODEBUG
#define oo_inline /*  */
#else
#define oo_inline inline
#endif

/**
 Policy: Determines whether asignment from immutables automatically takes "mutableCopy".
 */

#ifndef OOCopyImmutable
#define OOCopyImmutable copy // could also be "set" or left undefined (see below)
#endif

/**
 In threads without their own autorelease pool you may need to define this as "OOPool pool"
 */

#ifndef OOPoolIfRequired
#define OOPoolIfRequired /* OOPool pool */
#endif

/**
 If you ask me this is how "nil" should be defined
 */
#define OONil (id)nil
#define OONull OO_BRIDGE(id)kCFNull
#define OOLong long
#define OOAddress unsigned long

// containers for OOStrings
#define OOId OOReference<id>
#define cOOString const OOString &
#define cOOStringArray const OOStringArray &
#define OOStringArray OOArray<OOString>
#define OOStringArrayArray OOArray<OOStringArray >
#define OOStringDictionary OODictionary<OOString>
#define OOStringDictionaryArray OOArray<OOStringDictionary >

#define OOStrArray OOStringArray
#define OOStrDict OOStringDictionary
#define OOStrDicts OOStringDictionaryArray
#define OOStringDict OOStringDictionary

// containers for OONumbers
#define OONumberArray OOArray<OONumber>
#define OONumberDict OODictionary<OONumber>

// for slicing arrays
inline NSRange OORange( NSUInteger start, NSInteger end  ) {
	return NSMakeRange( start, end<0 || end == NSNotFound ? end : end-start );
}
#define OORangeFrom(_start) OORange(_start,NSNotFound)
#define OORangeAll() OORangeFrom(0)
#define OOSlice OOArray<id>

// variations as per taste
#define OORef OOReference
#define OOPtr OOPointer
#define OOStr OOString
#define OOStrs OOStringArray
#define OOData OOReference<NSData *>
#define OODate OOReference<NSDate *>
#define OODict OODictionary
#define OOHash OODictionary
#define OOList OOArray

#define OOHome() OOString(NSHomeDirectory())


// stack traces for debug warnings
static void OODump( NSString *format, ... ) {
	va_list argp;
    va_start(argp, format);
	NSLogv( format, argp );
	va_end( argp );

    @try {
        @throw [NSException alloc];
    }
    @catch ( NSException *ex ) {
        NSLog( @"%@", [ex callStackSymbols] );
    }

	// (*(int *)0)++; // invalid memory access hands control over to debugger...
}

#ifdef OODEBUG
#define OOPrint( _obj ) NSLog( @"%s:%d - %s = %@", __FILE__, __LINE__, #_obj, *_obj )
#else
#define OOPrint( _obj ) if(0) _obj
#endif

// forward referenced class templates
template <typename ETYPE> class OODictionary;
template <typename ETYPE> class OOArraySub;
template <typename ETYPE> class OODictionarySub;
template <typename ETYPE> class OOArraySlice;
template <typename ETYPE> class OODictionarySlice;
template <typename ETYPE,typename RTYPE,typename STYPE>
class OOSubscript;
class OOString;
class OONodeArraySub;
class OONodeSub;
class OONode;

/*=================================================================================*/
/*============================== Basic ref managment ========================*/

/**
 A class managing basic ref counting references retain/release mechansim for use in
 instance variables which will not allow constructors or destructors. Use the &operator
 to get a pointer with "autorelease" scope for use in the rest of your program.
 
 To free the ref either assign nil references the "=" operator or call use the ~ operator
 which returns a transient ref. Use &~var to free the ref with autorelrease scope.
 
 Usage:
 <pre>
 OOReference<NSString *> immutableRef = @"STRING"; // take referrence to a string
 OOReference<NSMutableArray *> mutableRef <<= [NSArray array]; // take mutable copy
 NSMutableArray *ptr = &amp;mutableRef; // get autoreleasing pointer to original object
 NSMutableArray *ptr = *mutableRef; // get pointer to original object
 ~mutableRef; // clear out pointer and remove "release" object.
 
 - (NSString *)function:(NSString *)str {
 OOReference<NSString *> ref = str; // take ref
 
 // do something
 
 return &amp;str; // get autoreleasing pointer to return
 // ref is discarded when object destructed on function exit.
 } 
 </pre>
 */

template <typename RTYPE>
class OOReference {
	RTYPE ref;

    // determine Object-C class of reference
	oo_inline Class classOfReference() const {
		return [typeof *ref class];
	}

	// initialise ref
	oo_inline RTYPE init( RTYPE val = OOEmpty ) OO_RETURNS {
		OOTrace( @"0x%08lx %s: %@", (OOAddress)this, "INIT", val != (id)kCFNull ? (id)val : @"(NULL)" );
		ref = nil;
		return set( val );
	}

protected:
	// clear out referrence
	oo_inline void destruct() {
		OOTrace( @"0x%08lx %s: 0x%08lx = %@", (OOAddress)this, "DESTRUCT", (OOAddress)ref, ref );
		rawset( (RTYPE)nil );
	}

	// replace reference
#ifdef __OBJC_GC__
	oo_inline virtual id rawset( RTYPE val ) OO_RETURNS {
#else
    oo_inline RTYPE rawset( RTYPE val ) OO_RETURNS {
#endif
        RTYPE old = ref;
		ref = val;
		if ( val != nil && val != (id)kCFNull ) {
			OORetain( @"0x%08lx %s#%ld: 0x%08lx = %@", (OOAddress)this, "RETAIN", 
                     (OOLong)OO_RETAINCOUNT( val ), (OOAddress)val, val );
		}
		if ( old != nil && old != (id)kCFNull ) {
			OORelease( @"0x%08lx %s#%ld: 0x%08lx = %@", (OOAddress)this, "RELEASE", 
                      (OOLong)OO_RETAINCOUNT( old ), (OOAddress)old, old );
			OO_RELEASE( old );
            old = nil;
		}
		return ref;
	}

	// replace referrence with retain
	oo_inline RTYPE set( RTYPE val ) OO_RETURNS {
		return rawset( OO_RETAIN( val ) );
	}

	// assignment from nil comes through as 0
	oo_inline RTYPE set( NSUInteger nilOrCapacity ) OO_RETURNS {
		if ( nilOrCapacity != 0 )
			rawset( [[classOfReference() alloc] initWithCapacity:nilOrCapacity] );
		else
			set( OONil );
		return ref;
	}

#ifdef OO_ARC
#define OO_AUTOTYPE id
#else
#define OO_AUTOTYPE RTYPE
#endif
	oo_inline OO_AUTOTYPE noalloc() const OO_AUTORETURNS {
		return ref ? ref : OO_AUTORELEASE( [[classOfReference() alloc] init] );
	}
	// get ref with "autorelease" scope
	oo_inline OO_AUTOTYPE autoget() const OO_AUTORETURNS {
		return OO_AUTORELEASE( OO_RETAIN( get() ) );
	}

public:
	// constructors to avoid shallow copy
	oo_inline OOReference() { init(); };
	///oo_inline OOReference( id obj ) { init( obj ); }
	oo_inline OOReference( RTYPE obj ) { init( obj ); }
	oo_inline OOReference( CFNullRef obj ) { init( OO_BRIDGE(id)obj ); }
	oo_inline OOReference( const OOReference &val ) { init( val.get() ); }
	oo_inline OOReference( const OOArraySub<RTYPE> &obj ) { init( obj.get() ); }
	oo_inline OOReference( const OODictionarySub<RTYPE> &obj ) { init( obj.get() ); }

    oo_inline void *ptr() {
        return this;
    }

	// allocate new ref from RTYPE specified
	oo_inline RTYPE alloc() OO_RETURNS {
		if ( !*this ) {
			RTYPE val = [[classOfReference() alloc] init];
			OOTrace( @"0x%08lx %s %@", (OOAddress)this, "ALLOC", val );
			rawset( val );
		}
#ifndef OOCopyImmutable
#define OOCopyImmutable set
		// alternate strategy to ensure mutability
		// does not work for objects in containers
		else if ( [ref class] != classOfReference() )
			copy( ref );
#endif
		return ref;
	}
	// copy any immutable objects
	oo_inline void copy( RTYPE val ) {
		RTYPE obj = [val mutableCopyWithZone:NULL];
		OOTrace( @"0x%08lx %s: 0x%08lx -> 0x%08lx = %@", (OOAddress)this, "COPY", (OOAddress)val, (OOAddress)obj, obj );
		rawset( obj );
	}

	// get existing ref
	oo_inline RTYPE get() const OO_RETURNS {
		return ref;
	}

	// for cast operator, somehow OO_RETURNS is not required
	oo_inline operator RTYPE () const /*OO_RETURNS*/ { return get(); }
	oo_inline RTYPE operator -> () const OO_RETURNS { return get(); }
	oo_inline OO_AUTOTYPE operator & () const OO_AUTORETURNS { return autoget(); }
	oo_inline RTYPE operator * () const OO_RETURNS { return !*this ? nil : get(); }
	oo_inline BOOL operator ! () const { return !ref || ref == (id)kCFNull; }

	// assign (mutable) copy from source
	oo_inline OOReference &operator <<= ( const OOReference &val ) {
        copy( val.get() );
        return *this;
    }

	// assigment by reference
	oo_inline OOReference &operator = ( const OOReference &val ) { set( val.get() ); return *this; }
	oo_inline OOReference &operator = ( CFNullRef val ) { set( val ); return *this; }
	oo_inline OOReference &operator = ( RTYPE val ) { set( val ); return *this; }
	oo_inline OOReference &operator = ( int val ) { set( val ); return *this; }

	// comparison
	oo_inline BOOL operator == ( const OOReference &val ) const { return [get() isEqual:val.get()]; }
	oo_inline BOOL operator != ( const OOReference &val ) const { return !(*this == val); }

	/// for OOArray<id>
	oo_inline OOReference &operator += ( id val ) {
		[alloc() addObject:val];
		return *this;
	}

	// might be useful...
	oo_inline id operator [] ( NSString *key ) const { return [ref valueForKey:key]; }

	oo_inline OOReference operator ~ () {
		// take temporary ref and return it
		// in case &~var construct is used
		OOReference save = ref;
		this->destruct();
		return save;
	}

	oo_inline ~OOReference() { this->destruct(); }
};

/**
 Scope based auto-release pool.
 */

#ifndef OO_ARC
class OOPool : public OOReference<NSAutoreleasePool *> {
public:
	oo_inline OOPool() {
		rawset( [NSAutoreleasePool new] );
	}
};
#else
class OOPool {
public:
    oo_inline OOPool() {
    }
};
#endif

/*=================================================================================*/
/*=============================== Array classes ===================================*/


/**
 NSMutableArray wrapper allowing subscript syntax by index and various other operators.
 The integer value of an OArray object is the number of elements e.g. "for ( i=0 ; i<array ; i++ )".
 
 <table cellspacing=0><tr><th>operator<th>inplace<th>binary<th>argument
 <tr><td>assignment<td>&nbsp;<td>=<td>array
 <tr><td>copy<td>&nbsp;<td>&lt;&lt;=<td>array
 <tr><td>add object(s)<td>+=<td>+<td>object (or array)
 <tr><td>remove object(s)<td>-=<td>-<td>object (or array)
 <tr><td>replicate members(s)<td>*=<td>*<td>count
 <tr><td>split alternate members<td><td>/<td>count e.g 2 for even/odd members
 <tr><td>filter array<td>&=<td>&<td>array
 <tr><td>merge array<td>|=<td>|<td>array
 <tr><td>subscript<td>&nbsp;<td>[]<td>int, object or range
 </table>
 
 Usage:
 <pre>
 \@interface ExampleClass {
	OOArray array;
 }
 \@end
 
 \@implementation ExampleClass
 - (void) aFunction {
     array += @"STRING"; // append to array
     array[1] = @"STRING"; // set position directly
     NSString *str = &amp;array[1]; // take polinter to item 1
     ~array[0]; // remove element at position 0
 }

 - (NSMutableArray *)function {
 OOArray<NSString *> array; // declare array of strings
 for ( int i=0 ; i<20 )
 array[i] = @"STRING";
 return &amp;array; // return autoreleasing pointer to array allocated
 }
 
 \@end
 </pre> 
 */

class OOStringSearch;
typedef id (^OOBlock)(id);

template <typename ETYPE>
class OOArray : public OOReference<NSMutableArray *> {
#ifdef __OBJC_GC__
    NSMutableArray *ref2;
	oo_inline virtual id rawset( NSMutableArray *val ) OO_RETURNS {
		return OOReference<NSMutableArray *>::rawset( ref2 = val );
	}
#endif
public:
	oo_inline OOArray() {}
	oo_inline OOArray( id obj ) { *this = obj; }
	oo_inline OOArray( CFNullRef obj ) { set( OO_BRIDGE(id)obj ); }
	oo_inline OOArray( const OOArray &arr ) { *this = arr; }
	oo_inline OOArray( const OOArraySub<ETYPE> &sub ) { *this = sub; }
	oo_inline OOArray( const OODictionarySub<ETYPE> &sub ) { *this = sub; }
	oo_inline OOArray( const OOSubscript<OOString,NSMutableDictionary *,OOString> &sub ) { *this = sub; }
	oo_inline OOArray( const OOArraySlice<ETYPE> &sub ) { *this = sub; }
	oo_inline OOArray( const OODictionarySlice<ETYPE> &sub ) { *this = sub; }
	oo_inline OOArray( const OOReference<NSMutableArray *> &arr ) { *this = arr; }
	oo_inline OOArray( const OOReference<NSMutableDictionary *> &arr ) { *this = arr; }
	oo_inline OOArray( const OONodeSub &sub );
	oo_inline OOArray( int nilOrCapacity ) { *this = nilOrCapacity; }
	oo_inline OOArray( long nilOrCapacity ) { *this = nilOrCapacity; }
	oo_inline OOArray( NSMutableArray *arr ) { *this = arr; }
	oo_inline OOArray( NSArray *arr ) { *this = arr; }
	oo_inline OOArray( const char *val ) { *this = val; }
	oo_inline OOArray( const char **val ) { *this = val; }
	oo_inline OOArray( id e1, id e2, ... ) NS_REQUIRES_NIL_TERMINATION {
		va_list argp;
        va_start(argp, e2);
		*this += ETYPE(e1);
		while ( e2 ) {
			*this += ETYPE(e2);
			e2 = va_arg( argp, id );
		}
		va_end( argp );
	}

	oo_inline NSMutableArray *operator & () const { return autoget(); }
	oo_inline operator int () const { return !*this ? 0 : (int)[get() count]; }
	oo_inline int fetch( id parent /*= nil*/, cOOString sql /*= OOString( OONil )*/ );
	oo_inline OOString join( cOOString sep /*= OOString( @" " )*/ ) const;

	oo_inline OOArray &operator = ( id val ) { set( val ); return *this; }
	oo_inline OOArray &operator = ( NSMutableArray *val ) { set( val ); return *this; }
	oo_inline OOArray &operator = ( NSArray *val ) { OOCopyImmutable( (NSMutableArray *)val ); return *this; }
	oo_inline OOArray &operator = ( int nilOrCapacity ) { set( nilOrCapacity ); return *this; }
	oo_inline OOArray &operator = ( long nilOrCapacity ) { set( nilOrCapacity ); return *this; }
	oo_inline OOArray &operator = ( const OOArray &val ) { set( val.get() ); return *this; }
	oo_inline OOArray &operator = ( const OOArraySub<ETYPE> &val ) { set( val.get() ); return *this; }
	oo_inline OOArray &operator = ( const OODictionarySub<ETYPE> &val ) { set( val.get() ); return *this; }
	oo_inline OOArray &operator = ( const OOArraySlice<ETYPE> &val ) { OOCopyImmutable( val.get() ); return *this; }
	oo_inline OOArray &operator = ( const OODictionarySlice<ETYPE> &val ) { OOCopyImmutable( val.get() ); return *this; }
    oo_inline OOArray &operator = ( const OOStringSearch &search );
	oo_inline OOArray &operator = ( const OOReference<NSMutableArray *> &val ) { set( val.get() ); return *this; }
	oo_inline OOArray &operator = ( const OOReference<NSMutableDictionary *> &val ) {
#if 0
		// objxml.h support
		if ( [val objectForKey:kOOChildren] ) {
			[alloc() setArray:[val objectForKey:kOOChildren]];
			return *this;
		}
#endif
		OOArray<id> keys = [val allKeys];
		[alloc() removeAllObjects];
		for ( int i=0 ; i<keys ; i++ ) {
            id key = [*keys objectAtIndex:i];
			*this += (ETYPE)key;
			*this += (ETYPE)[val objectForKey:key];
		}
		return *this;
	}
	oo_inline OOArray &operator = ( const char *val );
	oo_inline OOArray &operator = ( const char **val );
	oo_inline OOArray &operator = ( const OONodeSub &sub );

	// subscript into array
	oo_inline OOArraySub<ETYPE> operator [] ( int sub ) const  {
		return OOArraySub<ETYPE>( this, sub );
	}
	oo_inline OOArraySub<ETYPE> operator [] ( long sub ) const  {
		return OOArraySub<ETYPE>( this, sub );
	}
	oo_inline OOArraySub<ETYPE> operator [] ( NSUInteger sub ) const  {
		return OOArraySub<ETYPE>( this, sub );
	}
	oo_inline OOArraySub<ETYPE> operator [] ( ETYPE sub ) const {
		return (*this)[(NSInteger)(get() ? [get() indexOfObject:sub] : NSNotFound)];
	}
	oo_inline OOArraySlice<ETYPE> operator [] ( const NSRange &subs ) const {
		return OOArraySlice<ETYPE>( this, subs );
	}

	oo_inline BOOL operator == ( NSArray *val ) const { return [get() isEqualToArray:val]; }
	oo_inline BOOL operator != ( NSArray *val ) const { return !operator == ( val ); }
	oo_inline BOOL operator == ( NSMutableArray *val ) const { return [get() isEqualToArray:val]; }
	oo_inline BOOL operator != ( NSMutableArray *val ) const { return !operator == ( val ); }
	oo_inline BOOL operator == ( const OOArray &val ) const { return [get() isEqualToArray:val]; }
	oo_inline BOOL operator != ( const OOArray &val ) const { return !operator == ( val ); }
	///oo_inline BOOL operator == ( const char *val ) const { return **this == OOString( val ); }
	///oo_inline BOOL operator != ( const char *val ) const { return **this != OOString( val ); }

	// add elements
	oo_inline OOArray &operator += ( ETYPE val );
	oo_inline OOArray &operator += ( const char *val ) {
		*this += (ETYPE)val;
		return *this;
	}
	oo_inline OOArray &operator += ( NSArray *val ) {
		*this += OOArray( val );
		return *this;
	}
	oo_inline OOArray &operator += ( const OOReference<NSMutableArray *> &val ) {
		[alloc() addObjectsFromArray:val.get()];
		return *this;
	}

	// remove elements (not returning it)
	oo_inline OOArray &operator -= ( int sub ) {
		[alloc() removeObjectAtIndex:sub < 0 ? (int)*this+sub : sub];
		return *this;
	}
	oo_inline OOArray &operator -= ( ETYPE val ) {
		[alloc() removeObject:val];
		return *this;
	}
	oo_inline OOArray &operator -= ( const OOReference<NSMutableArray *> &val ) {
		[alloc() removeObjectsInArray:val.get()];
		return *this;
	}

	// replicate
	oo_inline OOArray &operator *= ( NSUInteger count ) {
		OO_STRONG NSArray *arr = [get() copy];
		[get() removeAllObjects];
		for ( int i=0 ; i<count ; i++ )
			*this += arr;
        OO_RELEASE( arr );
		return *this;
	}
	oo_inline OOArray &operator *= ( const OOArray<ETYPE> &val ) {
        for ( int i=0 ; i<*this ; i++ )
            (*this)[i] *= val[i];
		return *this;
	}

	oo_inline OOArray &operator += ( SEL sel ) {
		[get() makeObjectsPerformSelector:sel];
		return *this;
	}
	oo_inline OOArray &operator += ( OOBlock block ) {
       for ( int i=0 ; i<*this ; i++ )
            (*this)[i] = (ETYPE)block( *(*this)[i] );
		return *this;
	}
	oo_inline OOArray &operator += ( char quote ) {
#ifdef __clang__ // crashes gcc
		return *this += ^ id(id val) {
            return [NSString stringWithFormat:@"%c%@%c", quote, val, quote];
        };
#else
        for ( int i=0 ; i<*this ; i++ )
            (*this)[i] = OOFormat( @"%c%@%c", quote, **(*this)[i], quote );
        return *this;
#endif
	}
	oo_inline OOArray &operator &= ( const OOReference<NSMutableArray *> &val ) {
		OO_STRONG NSArray *in = [get() copy];
		for ( int i=(int)[in count]-1 ; i>=0 ; i-- ) {
			id o = [in objectAtIndex:i];
			if ( !val || [val.get() indexOfObject:o] == NSNotFound )
				[get() removeObjectAtIndex:i];
		}
        OO_RELEASE( in );
		return *this;
	}
	oo_inline OOArray &operator |= ( const OOReference<NSMutableArray *> &val ) {
		for ( int i=0 ; i<[*val count] ; i++ ) {
			id o = [val.get() objectAtIndex:i];
			if ( [get() indexOfObject:o] == NSNotFound )
				[get() addObject:o];
		}
		return *this;
	}


	// binary equivalents
	oo_inline OOArray operator + ( ETYPE val ) const {
		OOArray arr; arr <<= noalloc(); arr += val; return arr;
	}
	oo_inline OOArray operator + ( char val ) const {
		OOArray arr; arr <<= noalloc(); arr += val; return arr;
	}
	oo_inline OOArray operator - ( ETYPE val ) const {
		OOArray arr; arr <<= noalloc(); arr -= val; return arr;
	}
	oo_inline OOArray operator + ( SEL sel ) const {
		OOArray<id> arr;
		for ( int i=0 ; i<*this ; i++ )
			arr += [*(*this)[i] performSelector:sel];
		return arr;
	}

	oo_inline OOArray operator + ( const OOReference<NSMutableArray *> &val ) const { 
		OOArray arr; arr <<= noalloc(); arr += val; return arr;
	}
	oo_inline OOArray operator - ( const OOReference<NSMutableArray *> &val ) const { 
		OOArray arr; arr <<= noalloc(); arr -= val; return arr;
	}
#if 000
	oo_inline OOArray operator * ( const OOReference<NSMutableArray *> &val ) const { 
		OOArray arr; arr <<= noalloc(); arr *= val; return arr;
	}
#endif
	oo_inline OOArray<OOArray<ETYPE> > operator / ( int split ) const { 
		OOArray<OOArray<ETYPE> > arr;
        for ( int i=0 ; i<*this ; i++ )
            (*arr[i%split]) += (*this)[i];
        return arr;
	}
	oo_inline OOArray operator & ( const OOReference<NSMutableArray *> &val ) const { 
		OOArray arr; arr <<= noalloc(); arr &= val; return arr;
	}
	oo_inline OOArray operator | ( const OOReference<NSMutableArray *> &val ) const {
		OOArray arr; arr <<= noalloc(); arr |= val; return arr;
	}

	// sort array (of strings)
	oo_inline OOStringArray operator + () const {
		OOPoolIfRequired;
		return [get() sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	}

	// array in reverse order
	oo_inline OOArray operator - () const {
		OOPoolIfRequired;
		return [[get() reverseObjectEnumerator] allObjects];
	}

	// shift first element
	oo_inline ETYPE operator -- () {
		return ~(*this)[0];
	}

	// pop last element
	oo_inline ETYPE operator -- ( int ) {
		return ~(*this)[-1];
	}
};

template <typename ETYPE>
oo_inline OOArray<ETYPE> operator * ( const OOArray<ETYPE> &left, int count ) {
	OOArray<ETYPE> out( (int)left*count );
	for ( int i=0 ; i<count ; i++ ) 
		out += left;
	return out;
}

template <typename ETYPE> ////
oo_inline OOArray<ETYPE> operator / ( const OOArray<ETYPE> &left, int count ) {
	OOArray<ETYPE> out( count );
	for ( int i=0 ; i<left ; i++ ) 
		out[i%count][i/count] = left[i];
	return out;
}

/*=================================================================================*/
/*============================== Dictionary classes ===============================*/

/**
 NSMutableDictionary wrapper for use in instance variables which allows subscripting
 by the key value. Use &~dict[@"key"] to remove the entry and return it with expression
 or autorelease scope. Subscripting can be applied recusively. ETYPE is type of leaf node.
 
 Operators:
 <table cellspacing=0><tr><th>operator<th>inplace<th>arguments
 <tr><td>take referernce<td>=<td>dictionary
 <tr><td>take copy<td>&lt;&lt;=<td>dictionary
 <tr><td>merge entries<td>+=<td>dictionary
 <tr><td>remove entries<td>-=<td>key or array
 <tr><td>sbuscript<td>[]<td>object (key) or "slice" of keys
 </table>
 
 Usage:
 <pre>

 - (void)function:(OODictionary<NSString *> &)dict {
	dict[@"ONE"][@"TWO"][@"THREE"] = @"Four"; // set valule
    NSString *str = *dict[@"ONE"][@"TWO"][@"THREE"]; // get value
    ~dict[@"ONE"][@"TWO"][@"THREE"]; // delete value
    // pointer "str" is invalid at this point
 }
 
 - (void)function:(NSMutableDictionary *)dict {
 OODictionary<OOString> ref <<= dict; // initialise mutable copy
 ref[@"KEY"] <<= @"";
 for ( int i=0 ; i<10 ; i++ )
 ref[@"KEY"] += "ABC";
 }
 
 </pre>
 */

template <typename ETYPE>
class OODictionary : public OOReference<NSMutableDictionary *> {
#ifdef __OBJC_GC__
    NSMutableDictionary *ref2;
protected:
	oo_inline virtual id rawset( NSMutableDictionary *val ) OO_RETURNS {
		return OOReference<NSMutableDictionary *>::rawset( ref2 = val );
	}
#endif
public:
	oo_inline OODictionary() {}
	oo_inline OODictionary( id obj ) { *this = obj; }
	oo_inline OODictionary( CFNullRef obj ) { set( OO_BRIDGE(id)obj ); }
	oo_inline OODictionary( const OODictionary &dict ) { *this = dict; }
	oo_inline OODictionary( const OOArraySub<ETYPE> &sub ) { *this = sub; }
	oo_inline OODictionary( const OODictionarySub<ETYPE> &sub ) { *this = sub; }
	oo_inline OODictionary( const OOReference<NSMutableDictionary *> &val ) { *this = val; }
	oo_inline OODictionary( const OOReference<NSMutableArray *> &val ) { *this = val; }
	oo_inline OODictionary( const OOStringSearch &search ) { *this = search; }
	oo_inline OODictionary( int nilOrCapacity ) { *this = nilOrCapacity; }
	oo_inline OODictionary( NSMutableDictionary *dict ) { *this = dict; }
	oo_inline OODictionary( NSDictionary *dict ) { *this = dict; }
	oo_inline OODictionary( const char *val ) { *this = val; }
	oo_inline OODictionary( const char **val ) { *this = val; }
	oo_inline OODictionary( id e1, id e2, ... ) NS_REQUIRES_NIL_TERMINATION {
		va_list argp; va_start(argp, e2);
		do 
			(*this)[e1] = ETYPE(e2);
		while ( (e1 = va_arg( argp, id )) && (e2 = va_arg( argp, id )) );
		va_end( argp );
	}

	oo_inline NSMutableDictionary *operator & () const { return autoget(); }
	///oo_inline operator int () const { return !*this ? 0 : (int)[[get() allKeys] count]; }

	oo_inline OODictionary &operator = ( id val ) { set( val ); return *this; }
	oo_inline OODictionary &operator = ( NSMutableDictionary *val ) { set( val ); return *this; }
	oo_inline OODictionary &operator = ( NSDictionary *val ) { OOCopyImmutable( (NSMutableDictionary *)val ); return *this; }
	oo_inline OODictionary &operator = ( int nilOrCapacity ) { set( nilOrCapacity ); return *this; }
	oo_inline OODictionary &operator = ( long nilOrCapacity ) { set( nilOrCapacity ); return *this; }
	oo_inline OODictionary &operator = ( const OODictionary &val ) { set( val.get() ); return *this; }
	oo_inline OODictionary &operator = ( const OOArraySub<ETYPE> &val ) { set( val.get() ); return *this; }
	oo_inline OODictionary &operator = ( const OODictionarySub<ETYPE> &val ) { set( val.get() ); return *this; }
	oo_inline OODictionary &operator = ( const OOReference<NSMutableDictionary *> &val ) { set( val.get() ); return *this; }
	oo_inline OODictionary &operator = ( const OOStringSearch &search );

	oo_inline OODictionary &operator = ( const OOReference<NSMutableArray *> &val ) {
		OOArray<id> keys = val;
		OOArray<ETYPE> values = val;
		[alloc() removeAllObjects];
		for ( int i=0 ; i<keys ; i+=2 )
#if OO_WAS_COMPILER_CRASH
			(*this)[*keys[i]] = *values[i+1]; /////
#else
			(*this)[[*keys objectAtIndex:i]] = *values[i+1]; /////
#endif
		return *this;
	}
	oo_inline OODictionary &operator = ( const char *val );
	oo_inline OODictionary &operator = ( const char **val );

	oo_inline BOOL operator == ( NSDictionary *val ) const { return [get() isEqualToDictionary:val]; }
	oo_inline BOOL operator != ( NSDictionary *val ) const { return !operator == ( val ); }
	oo_inline BOOL operator == ( NSMutableDictionary *val ) const { return [get() isEqualToDictionary:val]; }
	oo_inline BOOL operator != ( NSMutableDictionary *val ) const { return !operator == ( val ); }
	oo_inline BOOL operator == ( const OODictionary &val ) const { return [get() isEqualToDictionary:val]; }
	oo_inline BOOL operator != ( const OODictionary &val ) const { return !operator == ( val ); }

	// dctionary operations
	oo_inline OODictionary &operator -= ( id val ) { 
		[alloc() removeObjectForKey:val]; 
		return *this;
	}
	oo_inline OODictionary &operator -= ( const OOReference<NSMutableArray *> &val ) {
		[alloc() removeObjectsForKeys:val]; 
		return *this;
	}
	oo_inline OODictionary &operator -= ( const OOReference<NSMutableDictionary *> &val ) {
		[alloc() removeObjectsForKeys:[val allKeys]]; 
		return *this;
	}
	oo_inline OODictionary &operator *= ( const OODictionary<ETYPE> &val ) {
		OOArray<id> keys = [get() allKeys];
		for ( int i=0 ; i<keys ; i++ ) {
            id key = [keys objectAtIndex:i];
            (*this)[key] *= val[key];
        }
        return *this;
	}

	oo_inline OODictionary &operator &= ( const OODictionary &val ) {
#if OO_WAS_COMPILER_CRASH
		for ( id key in [get() allKeys] )
			if ( !val[key] )
				*this -= key;
		return *this;
#else
		OOArray<id> keys = [get() allKeys];
		for ( int i=0 ; i<keys ; i++ ) {
            id key = [keys objectAtIndex:i];
			if ( !val[key] )
				*this -= key;
        }
        return *this;
#endif
	}
	oo_inline OODictionary &operator |= ( const OODictionary &val ) {
		OOArray<id> keys = [val.get() allKeys];
		for ( int i=0 ; i<keys ; i++ ) {
            id key = [keys objectAtIndex:i];
			if ( !(*this)[key] )
				(*this)[key] = val[key];
        }
		return *this;
	}

	oo_inline OODictionary operator & ( const OODictionary &val ) const { 
		OODictionary out; out <<= noalloc(); return out &= val;
	}
	oo_inline OODictionary operator | ( const OODictionary &val ) const {
		OODictionary out; out <<= noalloc(); return out |= val;
	}

	oo_inline OODictionarySub<ETYPE> operator [] ( id sub ) const {
		return OODictionarySub<ETYPE>( this, sub );
	}
	oo_inline OODictionarySub<ETYPE> operator [] ( NSString *sub ) const {
		return OODictionarySub<ETYPE>( this, sub );
	}
    oo_inline OODictionarySub<ETYPE> operator [] ( cOOString sub ) const;
	oo_inline OODictionarySub<ETYPE> operator [] ( const OOArraySub<id> &sub ) const {
		return OODictionarySub<ETYPE>( this, sub );
	}
	oo_inline OODictionarySub<ETYPE> operator [] ( const OOArraySub<OOString> &sub ) const;
	oo_inline OODictionarySub<ETYPE> operator [] ( const OODictionarySub<OOString> &sub ) const;

	oo_inline OODictionarySlice<ETYPE> operator [] ( const OOReference<NSMutableArray *> &subs ) const {
		return OODictionarySlice<ETYPE>( this, subs.get() );
	}
};

/**
 Internal abstract superclass for subscripting operations by operator []
 */

template <typename ETYPE,typename RTYPE,typename STYPE>
class OOSubscript {
	friend class OONodeSub;

protected:
	// for x = int, NSString *, NSRange, OOArray<id>
	const OOReference<RTYPE *> *root; // for simple var[x]
	OOArraySub<RTYPE *> *aref; // for var...[0][x]
	OODictionarySub<RTYPE *> *dref; // for var...[@"KEY"][x]
    OO_UNSAFE id parentCache;

	oo_inline OOSubscript() {
		root = NULL; aref = NULL; dref = NULL;
        parentCache = nil;
		references = 0;
	}
	oo_inline ~OOSubscript () {
		if ( aref && --aref->references == 0 )
			delete aref;
		if ( dref && --dref->references == 0 )
			delete dref;
	}

	oo_inline id autoget() const OO_AUTORETURNS {
		return OO_AUTORELEASE( OO_RETAIN( get() ) );
	}

	oo_inline virtual id get( BOOL warn = YES ) const OO_RETURNS { return nil; }
	oo_inline virtual id set( id val ) const OO_RETURNS { return nil; }

public:
	int references;

	oo_inline id alloc( Class c ) const OO_RETURNS {
		OO_STRONG id parent = get( NO );
		if ( !parent ) {
			parent = [[c alloc] init];
			OOTrace( @"0x%08lx %s %@", (OOAddress)this, "VIVIFY", parent );
			OO_RELEASE( set( parent ) );
		}
#if 001
		else if ( ![parent isKindOfClass:c] ) {
			OOWarn( @"Reset: %@ == %@", [parent class], c );
			OO_RELEASE( set( parent = [parent mutableCopy] ) );
		}
#endif
		return parent;
	}

	RTYPE *parent( BOOL allocate ) const OO_RETURNS {
        if ( !parentCache )
            ((OOSubscript *)this)->parentCache = 
                allocate ?
                    root ? ((OOReference<RTYPE *> *)root)->alloc() : aref ?
                        aref->alloc( [RTYPE class] ) : dref->alloc( [RTYPE class] )
                :
                    root ? root->get() : aref ? aref->get( NO ) : dref->get( NO );
        return parentCache;
	}

	// unaries
	oo_inline ETYPE operator * () const OO_RETURNS { return get(); }
	oo_inline ETYPE operator -> () const OO_RETURNS { return get(); }
	oo_inline id operator & () const OO_AUTORETURNS { return autoget(); }
	oo_inline BOOL operator ! () const { return !get( NO ) || get( NO ) == (id)kCFNull; }

	oo_inline operator const char * () const { return [get() UTF8String]; }
	///oo_inline operator NSArray * () const { return get(); }
	///oo_inline operator NSString * () const { return get(); }
	///oo_inline operator BOOL () const { return !!*this; }

	// recursive subscripting
	oo_inline OOArraySub<STYPE> operator [] ( int sub ) const {
		return OOArraySub<STYPE>( (OODictionarySub<NSMutableArray *> *)this, sub );
	}
	oo_inline OOArraySlice<STYPE> operator [] ( const NSRange &sub ) const {
		return OOArraySlice<STYPE>( (OODictionarySub<NSMutableArray *> *)this, sub );
	}
	oo_inline OODictionarySub<STYPE> operator [] ( id sub ) const {
		return OODictionarySub<STYPE>( (OODictionarySub<NSMutableDictionary *> *)this, sub );
	}
	oo_inline OODictionarySub<STYPE> operator [] ( const CFStringRef sub ) const {
		return (*this)[OO_BRIDGE(id)sub];
	}
	oo_inline OODictionarySub<STYPE> operator [] ( cOOString sub ) const;
    oo_inline OODictionarySub<STYPE> operator [] ( const char *sub ) const;
	oo_inline OODictionarySlice<STYPE> operator [] ( const OOReference<NSMutableArray *> &sub ) const {
		return OODictionarySlice<STYPE>( (OODictionarySub<NSMutableDictionary *> *)this, sub );
	}

	// asignment
	oo_inline OOSubscript &operator <<= ( id<NSMutableCopying> val ) {
 		OO_RELEASE( set( [val mutableCopyWithZone:NULL] ) ); 
		return *this;
	}
	oo_inline OOSubscript &operator <<= ( const char *val );

	oo_inline OOSubscript &operator = ( NSArray *val ) { set( val ); return *this; }
	oo_inline OOSubscript &operator = ( NSDictionary *val ) { set( val ); return *this; }
	oo_inline OOSubscript &operator = ( NSMutableString *val ) { set( val ); return *this; }
	//oo_inline OOSubscript &operator = ( const char *val ) { *this <<= val; return *this; }
	oo_inline OOSubscript &operator = ( NSString *val ) { *this <<= val; return *this; }
	oo_inline OOSubscript &operator = ( NSNumber *val ) { set( val ); return *this; }
	oo_inline OOSubscript &operator = ( NSNull *val ) { set( val ); return *this; }

	// comparison
	oo_inline BOOL operator == ( const ETYPE val ) const { return **this == val; }
	oo_inline BOOL operator != ( const ETYPE val ) const { return **this != val; }
	oo_inline BOOL operator >= ( const ETYPE val ) const { return **this >= val; }
	oo_inline BOOL operator <= ( const ETYPE val ) const { return **this <= val; }
	oo_inline BOOL operator >  ( const ETYPE val ) const { return **this >  val; }
	oo_inline BOOL operator <  ( const ETYPE val ) const { return **this <  val; }

	oo_inline BOOL operator == ( const char *val ) const { return **this == ETYPE( val ); }
	oo_inline BOOL operator != ( const char *val ) const { return **this != ETYPE( val ); }
	oo_inline BOOL operator >= ( const char *val ) const { return **this >= ETYPE( val ); }
	oo_inline BOOL operator <= ( const char *val ) const { return **this <= ETYPE( val ); }
	oo_inline BOOL operator >  ( const char *val ) const { return **this >  ETYPE( val ); }
	oo_inline BOOL operator <  ( const char *val ) const { return **this <  ETYPE( val ); }

	oo_inline BOOL operator == ( const OOSubscript &val ) const { return **this == *val; }
	oo_inline BOOL operator != ( const OOSubscript &val ) const { return **this != *val; }
	oo_inline BOOL operator >= ( const OOSubscript &val ) const { return **this >= *val; }
	oo_inline BOOL operator <= ( const OOSubscript &val ) const { return **this <= *val; }
	oo_inline BOOL operator >  ( const OOSubscript &val ) const { return **this >  *val; }
	oo_inline BOOL operator <  ( const OOSubscript &val ) const { return **this <  *val; }

	// inplace operators
	oo_inline OOSubscript &operator += ( const ETYPE val ) { return *this = **this + val; }
	oo_inline OOSubscript &operator -= ( const ETYPE val ) { return *this = **this - val; }
	oo_inline OOSubscript &operator *= ( const ETYPE val ) { return *this = **this * val; }
	oo_inline OOSubscript &operator /= ( const ETYPE val ) { return *this = **this / val; }
	oo_inline OOSubscript &operator %= ( const ETYPE val ) { return *this = **this % val; }
	oo_inline OOSubscript &operator &= ( const ETYPE val ) { return *this = **this & val; }
	oo_inline OOSubscript &operator |= ( const ETYPE val ) { return *this = **this | val; }

	// binary operators
	oo_inline ETYPE operator + ( const ETYPE val ) const { return **this + val; }
	oo_inline ETYPE operator - ( const ETYPE val ) const { return **this - val; }
	oo_inline ETYPE operator * ( const ETYPE val ) const { return **this * val; }
	oo_inline ETYPE operator / ( const ETYPE val ) const { return **this / val; }
	oo_inline ETYPE operator % ( const ETYPE val ) const { return **this % val; }
	oo_inline ETYPE operator & ( const ETYPE val ) const { return **this & val; }
	oo_inline ETYPE operator | ( const ETYPE val ) const { return **this | val; }

	// concatenate others
	oo_inline ETYPE operator + ( NSString *val ) { return **this + val; }
#if 0000
	oo_inline ETYPE operator + ( const char *val ) { return **this + val; }
	oo_inline ETYPE operator + ( double val ) { return **this + val; }
	oo_inline ETYPE operator + ( int val ) { return **this + val; }
	oo_inline ETYPE operator + ( id val ) { return **this + val; }
#endif
};

/**
 Internal class to represent a subscript operation in an expression so it can
 be assigned to. You can also use the ~val[i] operation to remove the value
 from the array and return it with either expression or autorelease scope.
 If the index assigned to is beyond the end of the array it will be padded
 with kCFNull values to allow for sparse arrays.
 
 Usage:
<pre>
 - (AVAudioPlayer *)play:OOArray<AVAudioPlayer *> &amp;sounds {
 [*sounds[0] play]; // use * operator to get actual object ref
 return &amp;~sounds[0]; // delete item at index 0 and return pointer
 }
</pre>
 */

template <typename ETYPE>
class OOArraySub : public OOSubscript<ETYPE,NSMutableArray,ETYPE> {
	friend class OOArray<ETYPE>;
	friend class OOSubscript<ETYPE,NSMutableArray,ETYPE>;
	friend class OOSubscript<ETYPE,NSMutableDictionary,ETYPE>;
	friend class OOSubscript<OOArray<ETYPE>,NSMutableArray,ETYPE>;
	friend class OOSubscript<OOArray<ETYPE>,NSMutableDictionary,ETYPE>;
	friend class OONodeArraySub;
	friend class OONodeSub;

	NSInteger idx;

	oo_inline void setIdx( NSInteger sub ) {
		idx = sub < 0 ? [this->parent( NO ) count]+sub : sub;
	}
protected:
	oo_inline OOArraySub( const OOArray<ETYPE> *ref, NSInteger sub ) {
		this->root = ref; setIdx( sub );
	}
	oo_inline OOArraySub( OOArraySub<NSMutableArray *> *ref, NSInteger sub ) {
		this->aref = ref; setIdx( sub );
	}
	oo_inline OOArraySub( OODictionarySub<NSMutableArray *> *ref, NSInteger sub ) {
		this->dref = ref; setIdx( sub );
	}

public:
	oo_inline virtual id get( BOOL warn = YES ) const OO_RETURNS {
		NSMutableArray *arr = this->parent( NO );
		id ret = nil;
		if ( arr == (id)kCFNull )
            return nil;
        if ( idx < 0 )
            OOWarn( @"0x%08lx Excess negative index (%ld) beyond size of array (%ld)",
                   (OOAddress)this, (OOLong)idx-[arr count], (OOLong)[arr count] );
        else if ( idx < [arr count] )
            ret = [arr objectAtIndex:idx];
        else if ( idx == NSNotFound )
            ;
        else if ( warn )
            OOWarn( @"0x%08lx Array ref (%ld) beyond end of array (%ld)",
                   (OOAddress)this, (OOLong)idx, (OOLong)[arr count] );
		return ret != (id)kCFNull ? ret : nil;
	}
	oo_inline virtual id set ( id val ) const OO_RETURNS {
		NSMutableArray *arr = this->parent( YES );
		NSUInteger count = [arr count];
		if ( val == nil )
			val = OONoValue;
		if ( idx < 0 )
			OOWarn( @"0x%08lx Excess negative index (%ld) beyond size of array (%ld)",
                   (OOAddress)this, (OOLong)idx-[arr count], (OOLong)[arr count] );
		else if ( idx < count )
			[arr replaceObjectAtIndex:idx withObject:val];
		else if ( idx != NSNotFound ) {
			while ( count++ < idx )
				[arr addObject:(id)kCFNull]; // padding for sparse arrays
			[arr addObject:val];
		}
		return val;
	}

	oo_inline operator ETYPE () const /*OO_RETURNS*/ { return get(); }
	oo_inline operator NSUInteger () const { return idx; } ///
	//oo_inline operator NSString * () const { return get(); } ///
	//oo_inline operator NSArray * () const { return get(); } ///
	//// oo_inline operator id () const { return get(); } ///

	// assign and assign by mutable copy 
	oo_inline OOArraySub &operator = ( ETYPE val );// { set( val ); return *this; }
	oo_inline OOArraySub &operator = ( const char *val );/* { *this = OOString(val).get(); return *this; }*/
	oo_inline OOArraySub &operator = ( const OOArraySub<ETYPE> &val ) { set( val.get() ); return *this; }
	oo_inline OOArraySub &operator = ( const OODictionarySub<ETYPE> &val ) { set( val.get() ); return *this; }
	oo_inline OOArraySub &operator = ( const OOArraySlice<ETYPE> &val ) { set( val.get() ); return *this; }
	oo_inline OOArraySub &operator = ( const OODictionarySlice<ETYPE> &val ) { set( val.get() ); return *this; }
	oo_inline OOArraySub &operator = ( const OOReference<NSMutableArray *> &val ) { set( val.get() ); return *this; }
	oo_inline OOArraySub &operator = ( const OOReference<NSMutableDictionary *> &val ) { set( val.get() ); return *this; }

	// delete element and return it
	oo_inline ETYPE operator ~ () OO_RETURNS {
		ETYPE save = get( NO );
#ifndef OO_ARC
        const char *enc = @encode(ETYPE);
		if ( enc[0] == '@' )
			this->autoget();
#endif
		NSMutableArray *arr = this->parent( NO );
		if ( 0 <= idx && idx < [arr count] )
			[arr removeObjectAtIndex:idx];
		else
			OOWarn( @"0x%08lx Attempt to remove index (%ld) beyond end of array (%ld)",
                   (OOAddress)this, (OOLong)idx, (OOLong)[arr count] );
		return save;
	}
};

/**
 Internal class representing subscript by key in an expression so it 
 can be assigned to. Subscripts can be applied recursively "viviifying"
 the required Dictionaries (or arrays) at each node as required. Array
 and Dictionary acces can be mixed recursively.
 
 Usage:
 <pre>
 OODictionary<id> dict;
 dict[@"DICT"]["KEY"] <<= @"TEXT1";
 dict[@"ARRAY"][0] = <<= @"TEXT2";
 </pre>
 */

template <typename ETYPE>
class OODictionarySub : public OOSubscript<ETYPE,NSMutableDictionary,ETYPE> {
	friend class OODictionary<ETYPE>;
	friend class OOSubscript<ETYPE,NSMutableArray,ETYPE>;
	friend class OOSubscript<ETYPE,NSMutableDictionary,ETYPE>;
	friend class OODefaultsSub;
	friend class OONodeArraySub;
	friend class OONodeSub;
	friend class OONode;

	OOReference<id> key;

protected:
	oo_inline OODictionarySub( const OOReference<NSMutableDictionary *> *ref, id sub ) {
		this->root = ref; this->key = sub;
	}
	oo_inline OODictionarySub( OOArraySub<NSMutableDictionary *> *ref, id sub ) {
		this->aref = ref; this->key = sub;
	}
	oo_inline OODictionarySub( OODictionarySub<NSMutableDictionary *> *ref, id sub ) {
		this->dref = ref; this->key = sub;
	}

public:
	oo_inline virtual id get( BOOL warn = YES ) const OO_RETURNS {
		id parent = this->parent( NO ),
            value = parent != (id)kCFNull ? [parent objectForKey:this->key] : nil;
		return value != (id)kCFNull || 0 ? value : nil;
	}
	oo_inline virtual id set( id val ) const OO_RETURNS {
		if ( val == nil )
			val = OONoValue;
		[this->parent( YES ) setObject:val forKey:this->key];
		return val;
	}

	oo_inline operator ETYPE () const /*OO_RETURNS*/ { return get(); }

	// assign and assign by mutable copy
	oo_inline OODictionarySub &operator = ( ETYPE val );// { set( val ); return *this; }
	oo_inline OODictionarySub &operator = ( const char *val );// { *this = OOString(val).get(); return *this; }
	oo_inline OODictionarySub &operator = ( const OOArraySub<ETYPE> &val ) { set( val.get() ); return *this; }
	oo_inline OODictionarySub &operator = ( const OODictionarySub<ETYPE> &val ) { set( val.get() ); return *this; }
	oo_inline OODictionarySub &operator = ( const OOArraySlice<ETYPE> &val ) { set( val.get() ); return *this; }
	oo_inline OODictionarySub &operator = ( const OODictionarySlice<ETYPE> &val ) { set( val.get() ); return *this; }
	oo_inline OODictionarySub &operator = ( const OOReference<NSMutableArray *> &val ) { set( val.get() ); return *this; }
	oo_inline OODictionarySub &operator = ( const OOReference<NSMutableDictionary *> &val ) { set( val.get() ); return *this; }

	// delete entry and return its value
	oo_inline ETYPE operator ~ () OO_RETURNS {
		ETYPE save = get( NO );
#ifndef OO_ARC
        const char *enc = @encode(ETYPE);
		if ( enc[0] == '@' )
			this->autoget();
#endif
		[this->parent( NO ) removeObjectForKey:this->key];
		return save;
	}
};

/**
 Class representing taking a sub array of objects from an array references a NSRange
 and the subscript to the operator []. OORange takes arguments start, end
 whereas NSMakeRange takes argument start, length/count. Either can be used.
 
 Usage:
 <pre>
 OOStringArray strings = "a b c d";
 if ( strings[NSMakeRange(1,2)] == "a b" )
    ;// should be true
 strings[OORange(1,3)] = OOStringArray( "x y" );
 if ( strings == "a x y d" )
    ; // should be true
 </pre>
 */

template<typename ETYPE>
class OOArraySlice : public OOSubscript<OOArray<ETYPE>,NSMutableArray,ETYPE> {
	friend class OOArray<ETYPE>;
	friend class OOSubscript<ETYPE,NSMutableArray,ETYPE>;
	friend class OOSubscript<ETYPE,NSMutableDictionary,ETYPE>;
	friend class OOSubscript<OOArray<ETYPE>,NSMutableArray,ETYPE>;
	friend class OOSubscript<OOArray<ETYPE>,NSMutableDictionary,ETYPE>;

	NSRange slice;

	oo_inline void setSlice( const NSRange &sub ) {
        NSUInteger parentCount = [this->parent( NO ) count];
		if ( (NSInteger)((slice = sub).location) < 0 )
			slice.location = parentCount+slice.location;
        if ( slice.length == NSNotFound )
			slice.length = parentCount-slice.location;
        else if ( slice.length > parentCount-slice.location ) {
            OOWarn( @"0x%08lx Slice length (%ld) beyond availble (%ld-%ld)",
                   (OOAddress)this, (OOLong)slice.length, (OOLong)parentCount, (OOLong)slice.location );
            slice.length = parentCount-slice.location;
        }
	}

	oo_inline OOArraySlice( const OOArray<ETYPE> *ref, const NSRange &sub ) {
		this->root = ref; setSlice( sub );
	}
	oo_inline OOArraySlice( OOArraySub<NSMutableArray *> *ref, const NSRange &sub ) {
		this->aref = ref; setSlice( sub );
	}
	oo_inline OOArraySlice( OODictionarySub<NSMutableArray *> *ref, const NSRange &sub ) {
		this->dref = ref; setSlice( sub );
	}

public:
	oo_inline virtual id get( BOOL warn = YES ) const OO_RETURNS {
		return [this->parent( NO ) subarrayWithRange:slice];
	}

    oo_inline OOArray<ETYPE> operator * () const { return get(); }
    oo_inline operator NSArray * () const { return get(); }

	oo_inline BOOL operator == ( const OOArray<ETYPE> &in ) const {
		return [get() isEqualToArray:in.get()];
	}
	oo_inline BOOL operator == ( const char *val ) const { return **this == OOArray<ETYPE>( val ); }
	oo_inline BOOL operator != ( const char *val ) const { return **this != OOArray<ETYPE>( val ); }

	oo_inline OOArraySlice &operator = ( const OOArray<ETYPE> &in ) {
        [this->parent( YES ) replaceObjectsInRange:slice withObjectsFromArray:in];
		return *this;
	}
    oo_inline OOArraySlice &operator = ( const OOArraySlice<ETYPE> &in ) {
        return *this = *in;
    }
    oo_inline OOArraySlice &operator = ( const OODictionarySlice<ETYPE> &in ) {
        return *this = *in;
    }
	oo_inline OOArray<ETYPE> operator ~ () {
		OOArray<ETYPE> save = get( NO );
		[this->parent( NO ) removeObjectsInRange:slice];
		return save;
	}
};

/**
 Class representing taking an array of objects from a dictionary references a
 "slice" of keys. Can be assigned to.
 
 Usage:
 <pre>
 OOStringDict dict = "a 1 b 2 c 3 d 4";
 if ( dict[OOSlice("b c")] == "2 3" )
   ;// should be true
 dict[OOSlice("b c")] = OOStringArray( "9 9" );
 if ( dict[OOSlice("b c")] = "9 9" )
   ; // should be true
 </pre>
 */

template<typename ETYPE>
class OODictionarySlice : public OOSubscript<OOArray<ETYPE>,NSMutableDictionary,ETYPE> {
	friend class OODictionary<ETYPE>;
	friend class OOSubscript<ETYPE,NSMutableArray,ETYPE>;
	friend class OOSubscript<ETYPE,NSMutableDictionary,ETYPE>;

	OOArray<id> slice;

	oo_inline OODictionarySlice( const OODictionary<ETYPE> *ref, NSMutableArray *sub ) {
		this->root = ref; slice = sub;
	}
	oo_inline OODictionarySlice( OOArraySub<NSMutableDictionary *> *ref, NSMutableArray *sub ) {
		this->aref = ref; slice = sub;
	}
	oo_inline OODictionarySlice( OODictionarySub<NSMutableDictionary *> *ref, NSMutableArray *sub ) {
		this->dref = ref; slice = sub;
	}
public:
	oo_inline virtual id get( BOOL warn = YES ) const OO_RETURNS {
		return [this->parent( NO ) objectsForKeys:slice notFoundMarker:(id)kCFNull];
	}

    oo_inline OOArray<ETYPE> operator * () const { return get(); }
    oo_inline operator NSArray * () const { return get(); }

	oo_inline BOOL operator == ( const OOArray<ETYPE> &in ) const {
		return [get() isEqualToArray:in.get()];
	}
	oo_inline BOOL operator == ( const char *val ) const { return **this == OOArray<ETYPE>( val ); }
	oo_inline BOOL operator != ( const char *val ) const { return **this != OOArray<ETYPE>( val ); }

	oo_inline OODictionarySlice &operator = ( const OOArray<ETYPE> &in ) {
		if ( (int)in != (int)slice )
			OOWarn( @"Slice assignment with key count [%d] different to value count [%d] - %@ c.f. %@", 
				   (int)slice, (int)in, *slice, *in );
        OODictionary<ETYPE> dict = this->parent( YES );
		for ( int i=0 ; i<slice ; i++ )
            dict[slice[i]] = in[i];
		return *this;
	}
    oo_inline OODictionarySlice &operator = ( const OOArraySlice<ETYPE> &in ) {
        return *this = *in;
    }
    oo_inline OODictionarySlice &operator = ( const OODictionarySlice<ETYPE> &in ) {
        return *this = *in;
    }
	oo_inline OOArray<ETYPE> operator ~ () {
		OOArray<ETYPE> save = get( NO );
		[this->parent( NO ) removeObjectsForKeys:slice];
		return save;
	}
};

#import "objstr.h"
#endif
#endif
