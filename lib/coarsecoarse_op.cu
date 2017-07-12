#include <transfer.h>
#include <color_spinor_field.h>
#include <color_spinor_field_order.h>
#include <gauge_field.h>
#include <gauge_field_order.h>
#include <complex_quda.h>
#include <index_helper.cuh>
#include <gamma.cuh>
#include <blas_cublas.h>

// this is the storage type used when computing the coarse link variables
// by using integers we have deterministic atomics
typedef int storeType;

#include <coarse_op.cuh>

namespace quda {

  template <typename Float, typename vFloat, int fineColor, int fineSpin, int coarseColor, int coarseSpin>
  void calculateYcoarse(GaugeField &Y, GaugeField &X,
			ColorSpinorField &uv, const Transfer &T, const GaugeField &g, const GaugeField &clover,
			const GaugeField &cloverInv, double kappa, double mu, double mu_factor, QudaDiracType dirac, QudaMatPCType matpc) {

    if (Y.Location() == QUDA_CPU_FIELD_LOCATION) {

      constexpr QudaFieldOrder csOrder = QUDA_SPACE_SPIN_COLOR_FIELD_ORDER;
      constexpr QudaGaugeFieldOrder gOrder = QUDA_QDP_GAUGE_ORDER;

      if (T.Vectors(Y.Location()).FieldOrder() != csOrder)
	errorQuda("Unsupported field order %d\n", T.Vectors(Y.Location()).FieldOrder());
      if (g.FieldOrder() != gOrder) errorQuda("Unsupported field order %d\n", g.FieldOrder());

      typedef typename colorspinor::FieldOrderCB<Float,fineSpin,fineColor,coarseColor,csOrder,vFloat> V;
      typedef typename colorspinor::FieldOrderCB<Float,2*fineSpin,fineColor,coarseColor,csOrder,vFloat> F;
      typedef typename gauge::FieldOrder<Float,fineColor*fineSpin,fineSpin,gOrder,true,vFloat> gFine;
      typedef typename gauge::FieldOrder<Float,fineColor*fineSpin,fineSpin,gOrder> cFine;
      typedef typename gauge::FieldOrder<Float,coarseColor*coarseSpin,coarseSpin,gOrder> gCoarse;
      typedef typename gauge::FieldOrder<Float,coarseColor*coarseSpin,coarseSpin,gOrder,true,storeType> gCoarseAtomic;

      const ColorSpinorField &v = T.Vectors(Y.Location());

      V vAccessor(const_cast<ColorSpinorField&>(v));
      F uvAccessor(const_cast<ColorSpinorField&>(uv));
      gFine gAccessor(const_cast<GaugeField&>(g));
      cFine cAccessor(const_cast<GaugeField&>(clover));
      cFine cInvAccessor(const_cast<GaugeField&>(cloverInv));
      gCoarse yAccessor(const_cast<GaugeField&>(Y));
      gCoarse xAccessor(const_cast<GaugeField&>(X));
      gCoarseAtomic yAccessorAtomic(const_cast<GaugeField&>(Y));
      gCoarseAtomic xAccessorAtomic(const_cast<GaugeField&>(X));

      calculateY<true,Float,fineSpin,fineColor,coarseSpin,coarseColor>
	(yAccessor, xAccessor, yAccessorAtomic, xAccessorAtomic,
	 uvAccessor, vAccessor, vAccessor, gAccessor, cAccessor, cInvAccessor,
	 Y, X, uv, const_cast<ColorSpinorField&>(v), v, kappa, mu, mu_factor, dirac, matpc,
	 T.fineToCoarse(Y.Location()), T.coarseToFine(Y.Location()));

    } else {

      constexpr QudaFieldOrder csOrder = QUDA_FLOAT2_FIELD_ORDER;
      constexpr QudaGaugeFieldOrder gOrder = QUDA_FLOAT2_GAUGE_ORDER;

      if (T.Vectors(Y.Location()).FieldOrder() != csOrder)
	errorQuda("Unsupported field order %d\n", T.Vectors(Y.Location()).FieldOrder());
      if (g.FieldOrder() != gOrder) errorQuda("Unsupported field order %d\n", g.FieldOrder());

      typedef typename colorspinor::FieldOrderCB<Float,fineSpin,fineColor,coarseColor,csOrder,vFloat> V;
      typedef typename colorspinor::FieldOrderCB<Float,2*fineSpin,fineColor,coarseColor,csOrder,vFloat> F;
      typedef typename gauge::FieldOrder<Float,fineColor*fineSpin,fineSpin,gOrder,true,vFloat> gFine;
      typedef typename gauge::FieldOrder<Float,fineColor*fineSpin,fineSpin,gOrder> cFine;
      typedef typename gauge::FieldOrder<Float,coarseColor*coarseSpin,coarseSpin,gOrder> gCoarse;
      typedef typename gauge::FieldOrder<Float,coarseColor*coarseSpin,coarseSpin,gOrder,true,storeType> gCoarseAtomic;

      const ColorSpinorField &v = T.Vectors(Y.Location());

      V vAccessor(const_cast<ColorSpinorField&>(v));
      F uvAccessor(const_cast<ColorSpinorField&>(uv));
      gFine gAccessor(const_cast<GaugeField&>(g));
      cFine cAccessor(const_cast<GaugeField&>(clover));
      cFine cInvAccessor(const_cast<GaugeField&>(cloverInv));
      gCoarse yAccessor(const_cast<GaugeField&>(Y));
      gCoarse xAccessor(const_cast<GaugeField&>(X));
      gCoarseAtomic yAccessorAtomic(const_cast<GaugeField&>(Y));
      gCoarseAtomic xAccessorAtomic(const_cast<GaugeField&>(X));

      calculateY<true,Float,fineSpin,fineColor,coarseSpin,coarseColor>
	(yAccessor, xAccessor, yAccessorAtomic, xAccessorAtomic,
	 uvAccessor, vAccessor, vAccessor, gAccessor, cAccessor, cInvAccessor,
	 Y, X, uv, const_cast<ColorSpinorField&>(v), v, kappa, mu, mu_factor, dirac, matpc,
	 T.fineToCoarse(Y.Location()), T.coarseToFine(Y.Location()));

    }

  }

  // template on the number of coarse degrees of freedom
  template <typename Float, typename vFloat, int fineColor, int fineSpin>
  void calculateYcoarse(GaugeField &Y, GaugeField &X,
			ColorSpinorField &uv, const Transfer &T, const GaugeField &g, const GaugeField &clover,
			const GaugeField &cloverInv, double kappa, double mu, double mu_factor, QudaDiracType dirac, QudaMatPCType matpc) {
    if (T.Vectors().Nspin()/T.Spin_bs() != 2) 
      errorQuda("Unsupported number of coarse spins %d\n",T.Vectors().Nspin()/T.Spin_bs());
    const int coarseSpin = 2;
    const int coarseColor = Y.Ncolor() / coarseSpin;

    if (coarseColor == 2) { 
      calculateYcoarse<Float,vFloat,fineColor,fineSpin,2,coarseSpin>(Y, X, uv, T, g, clover, cloverInv, kappa, mu, mu_factor, dirac, matpc);
#if 0
    } else if (coarseColor == 8) {
      calculateYcoarse<Float,vFloat,fineColor,fineSpin,8,coarseSpin>(Y, X, uv, T, g, clover, cloverInv, kappa, mu, mu_factor, dirac, matpc);
    } else if (coarseColor == 16) {
      calculateYcoarse<Float,vFloat,fineColor,fineSpin,16,coarseSpin>(Y, X, uv, T, g, clover, cloverInv, kappa, mu, mu_factor, dirac, matpc);
#endif
    } else if (coarseColor == 24) {
      calculateYcoarse<Float,vFloat,fineColor,fineSpin,24,coarseSpin>(Y, X, uv, T, g, clover, cloverInv, kappa, mu, mu_factor, dirac, matpc);
    } else if (coarseColor == 32) {
      calculateYcoarse<Float,vFloat,fineColor,fineSpin,32,coarseSpin>(Y, X, uv, T, g, clover, cloverInv, kappa, mu, mu_factor, dirac, matpc);
    } else {
      errorQuda("Unsupported number of coarse dof %d\n", Y.Ncolor());
    }
  }

  // template on fine spin
  template <typename Float, typename vFloat, int fineColor>
  void calculateYcoarse(GaugeField &Y, GaugeField &X,
			ColorSpinorField &uv, const Transfer &T, const GaugeField &g, const GaugeField &clover,
			const GaugeField &cloverInv, double kappa, double mu, double mu_factor, QudaDiracType dirac, QudaMatPCType matpc) {
    if (T.Vectors().Nspin() == 2) {
      calculateYcoarse<Float,vFloat,fineColor,2>(Y, X, uv, T, g, clover, cloverInv, kappa, mu, mu_factor, dirac, matpc);
    } else {
      errorQuda("Unsupported number of spins %d\n", T.Vectors().Nspin());
    }
  }

  // template on fine colors
  template <typename Float, typename vFloat>
  void calculateYcoarse(GaugeField &Y, GaugeField &X,
			ColorSpinorField &uv, const Transfer &T, const GaugeField &g, const GaugeField &clover,
			const GaugeField &cloverInv, double kappa, double mu, double mu_factor, QudaDiracType dirac, QudaMatPCType matpc) {
    if (g.Ncolor()/T.Vectors().Nspin() == 2) {
      calculateYcoarse<Float,vFloat,2>(Y, X, uv, T, g, clover, cloverInv, kappa, mu, mu_factor, dirac, matpc);
#if 0
    } else if (g.Ncolor()/T.Vectors().Nspin() == 8) {
      calculateYcoarse<Float,vFloat,8>(Y, X, uv, T, g, clover, cloverInv, kappa, mu, mu_factor, dirac, matpc);
    } else if (g.Ncolor()/T.Vectors().Nspin() == 16) {
      calculateYcoarse<Float,vFloat,16>(Y, X, uv, T, g, clover, cloverInv, kappa, mu, mu_factor, dirac, matpc);
#endif
    } else if (g.Ncolor()/T.Vectors().Nspin() == 24) {
      calculateYcoarse<Float,vFloat,24>(Y, X, uv, T, g, clover, cloverInv, kappa, mu, mu_factor, dirac, matpc);
    } else if (g.Ncolor()/T.Vectors().Nspin() == 32) {
      calculateYcoarse<Float,vFloat,32>(Y, X, uv, T, g, clover, cloverInv, kappa, mu, mu_factor, dirac, matpc);
    } else {
      errorQuda("Unsupported number of colors %d\n", g.Ncolor());
    }
  }

  //Does the heavy lifting of creating the coarse color matrices Y
  void calculateYcoarse(GaugeField &Y, GaugeField &X, ColorSpinorField &uv,
			const Transfer &T, const GaugeField &g, const GaugeField &clover, const GaugeField &cloverInv,
			double kappa, double mu, double mu_factor, QudaDiracType dirac, QudaMatPCType matpc) {
    checkPrecision(X, Y, clover, cloverInv);
    checkPrecision(g, uv, T.Vectors(X.Location()));

    printfQuda("Computing Y field......\n");
    if (Y.Precision() == QUDA_DOUBLE_PRECISION) {
#ifdef GPU_MULTIGRID_DOUBLE
      if (T.Vectors(X.Location()).Precision() == QUDA_DOUBLE_PRECISION) {
	calculateYcoarse<double,double>(Y, X, uv, T, g, clover, cloverInv, kappa, mu, mu_factor, dirac, matpc);
      } else {
	errorQuda("Unsupported precision %d\n", Y.Precision());
      }
#else
      errorQuda("Double precision multigrid has not been enabled");
#endif
    } else if (Y.Precision() == QUDA_SINGLE_PRECISION) {
      if (T.Vectors(X.Location()).Precision() == QUDA_SINGLE_PRECISION) {
	calculateYcoarse<float,float>(Y, X, uv, T, g, clover, cloverInv, kappa, mu, mu_factor, dirac, matpc);
      } else if (T.Vectors(X.Location()).Precision() == QUDA_HALF_PRECISION) {
	calculateYcoarse<float,short>(Y, X, uv, T, g, clover, cloverInv, kappa, mu, mu_factor, dirac, matpc);
      } else {
	errorQuda("Unsupported precision %d\n", T.Vectors(X.Location()).Precision());
      }
    } else {
      errorQuda("Unsupported precision %d\n", Y.Precision());
    }
    printfQuda("....done computing Y field\n");
  }

  //Calculates the coarse color matrix and puts the result in Y.
  //N.B. Assumes Y, X have been allocated.
  void CoarseCoarseOp(GaugeField &Y, GaugeField &X, const Transfer &T,
		      const GaugeField &gauge, const GaugeField &clover, const GaugeField &cloverInv,
		      double kappa, double mu, double mu_factor, QudaDiracType dirac, QudaMatPCType matpc) {

    QudaPrecision precision = Y.Precision();
    QudaFieldLocation location = checkLocation(X, Y, gauge, clover, cloverInv);

    //Create a field UV which holds U*V.  Has the same similar
    //structure to V but double the number of spins so we can store
    //the four distinct block chiral multiplications in a single UV
    //computation.
    ColorSpinorParam UVparam(T.Vectors(location));
    UVparam.create = QUDA_ZERO_FIELD_CREATE;
    UVparam.location = location;
    UVparam.nSpin *= 2; // so nSpin == 4
    UVparam.precision = T.Vectors(location).Precision();

    ColorSpinorField *uv = ColorSpinorField::Create(UVparam);

    calculateYcoarse(Y, X, *uv, T, gauge, clover, cloverInv, kappa, mu, mu_factor, dirac, matpc);

    delete uv;
  }
  
} //namespace quda
